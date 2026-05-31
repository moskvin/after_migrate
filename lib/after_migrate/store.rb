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
  end
end
