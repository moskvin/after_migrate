# frozen_string_literal: true

require 'fileutils'
require 'json'

module AfterMigrate
  module Stores
    class Memory
      attr_reader :affected_tables

      def initialize
        @affected_tables = Concurrent::Map.new
      end

      def merge_tables(schema, table_names)
        return if table_names.blank?

        set = affected_tables.compute_if_absent(schema) { Concurrent::Set.new }
        set.merge(table_names)
      end

      def reset!
        @affected_tables = Concurrent::Map.new
      end
    end

    class FileStore < Memory
      attr_reader :path, :run_id

      def initialize(path:, run_id: nil)
        super()
        @path = path.to_s
        @run_id = run_id.to_s.presence
      end

      def affected_tables
        load_into_memory
        super
      end

      def merge_tables(schema, table_names)
        return if table_names.blank?

        with_lock do
          merge_into_memory(read_schemas)
          merge_into_memory(schema => table_names)
          write_schemas(memory_to_hash)
        end
      end

      def reset!
        super
        with_lock { ::FileUtils.rm_f(path) }
      end

      private

      def load_into_memory
        with_lock { merge_into_memory(read_schemas) }
      end

      def merge_into_memory(schemas)
        schemas.each do |schema, table_names|
          set = @affected_tables.compute_if_absent(schema) { Concurrent::Set.new }
          set.merge(table_names)
        end
      end

      def read_schemas
        return {} unless ::File.exist?(path)

        payload = JSON.parse(::File.read(path))
        return {} if run_id && payload['run_id'].to_s != run_id

        payload.fetch('schemas', {})
      rescue JSON::ParserError
        {}
      end

      def write_schemas(schemas)
        ::FileUtils.mkdir_p(::File.dirname(path))
        temp_path = "#{path}.#{$PROCESS_ID}.tmp"
        ::File.write(temp_path, JSON.pretty_generate({ run_id:, schemas: }))
        ::File.rename(temp_path, path)
      ensure
        ::FileUtils.rm_f(temp_path) if temp_path && ::File.exist?(temp_path)
      end

      def memory_to_hash
        @affected_tables.keys.sort.each_with_object({}) do |schema, hash|
          hash[schema] = @affected_tables[schema].to_a.sort
        end.sort.to_h
      end

      def with_lock
        ::FileUtils.mkdir_p(::File.dirname(path))
        ::File.open("#{path}.lock", ::File::RDWR | ::File::CREAT, 0o644) do |file|
          file.flock(::File::LOCK_EX)
          yield
        end
      end
    end

    class RedisStore < Memory
      attr_reader :key_prefix, :run_id, :ttl

      def initialize(redis:, key_prefix: 'after_migrate', run_id: nil, ttl: 24 * 60 * 60)
        super()
        @redis = redis
        @key_prefix = key_prefix.to_s
        @run_id = run_id.to_s.presence || 'default'
        @ttl = ttl.to_i
      end

      def affected_tables
        load_into_memory
        super
      end

      def merge_tables(schema, table_names)
        return if table_names.blank?

        with_redis do |redis|
          redis.sadd(index_key, schema)
          redis.sadd(schema_key(schema), table_names.to_a)
          expire_keys(redis, schema)
        end
        merge_into_memory(schema => table_names)
      end

      def reset!
        super
        with_redis do |redis|
          schemas = redis.smembers(index_key)
          keys = schemas.map { |schema| schema_key(schema) }
          redis.del(*(keys + [index_key])) if keys.any?
          redis.del(index_key) if keys.empty?
        end
      end

      private

      def load_into_memory
        with_redis do |redis|
          redis.smembers(index_key).each do |schema|
            merge_into_memory(schema => redis.smembers(schema_key(schema)))
          end
        end
      end

      def merge_into_memory(schemas)
        schemas.each do |schema, table_names|
          set = @affected_tables.compute_if_absent(schema) { Concurrent::Set.new }
          set.merge(table_names)
        end
      end

      def index_key
        "#{base_key}:schemas"
      end

      def schema_key(schema)
        "#{base_key}:schema:#{schema}"
      end

      def base_key
        "#{key_prefix}:#{run_id}"
      end

      def expire_keys(redis, schema)
        return unless ttl.positive?

        redis.expire(index_key, ttl)
        redis.expire(schema_key(schema), ttl)
      end

      def with_redis(&block)
        redis = resolved_redis
        return redis.with { |connection| block.call(connection) } if redis.respond_to?(:with)

        block.call(redis)
      end

      # Memoized so a plain client or a `-> { Redis.new }` proc only ever
      # produces one connection per store instance. Without this, `with_redis`
      # re-invokes the proc on every merge_tables/affected_tables call, opening
      # a fresh unpooled connection per SQL statement — which exhausts the
      # Redis server's connection limit under parallel/multi-tenant migrations.
      # Pass a ConnectionPool as config.redis for thread-safe concurrency.
      def resolved_redis
        @resolved_redis ||= begin
          client = @redis.respond_to?(:call) ? @redis.call : @redis
          client ||= Redis.new if defined?(Redis)
          client || raise('AfterMigrate Redis store requires config.redis or the redis gem')
        end
      end
    end
  end
end
