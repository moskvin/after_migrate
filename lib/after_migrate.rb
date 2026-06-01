# frozen_string_literal: true

require 'after_migrate/version'
require 'after_migrate/store'
require 'after_migrate/collector'
require 'after_migrate/executor'
require 'after_migrate/railtie'

module AfterMigrate
  class Configuration
    attr_accessor :enabled, :verbose, :vacuum, :analyze, :rake_tasks_enhanced, :defer,
                  :store, :run_id, :store_options

    def initialize
      @enabled = true
      @verbose = true
      @vacuum = true
      @analyze = 'only_affected_tables'
      @rake_tasks_enhanced = true
      @defer = true
      @store = :memory
      @run_id = ENV.fetch('AFTER_MIGRATE_RUN_ID', 'default')
      @store_options = {
        file: {
          path: 'tmp/after_migrate/affected_tables.json'
        },
        redis: {
          client: nil,
          key_prefix: 'after_migrate',
          ttl: 24 * 60 * 60
        }
      }
    end

    def store_path
      store_options_for(:file)[:path]
    end

    def store_path=(value)
      store_options_for(:file)[:path] = value
    end

    def redis
      store_options_for(:redis)[:client]
    end

    def redis=(value)
      store_options_for(:redis)[:client] = value
    end

    def redis_key_prefix
      store_options_for(:redis)[:key_prefix]
    end

    def redis_key_prefix=(value)
      store_options_for(:redis)[:key_prefix] = value
    end

    def redis_ttl
      store_options_for(:redis)[:ttl]
    end

    def redis_ttl=(value)
      store_options_for(:redis)[:ttl] = value
    end

    def store_options_for(store_name)
      store_options[store_name.to_sym] ||= {}
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def log(msg)
      warn "[after_migrate] #{msg}" if AfterMigrate.configuration.verbose
    end

    # Persistent cross-migration store: schema_name => Concurrent::Set<table_name>
    def affected_tables
      store.affected_tables
    end

    def merge_tables(schema, table_names)
      store.merge_tables(schema, table_names)
    end

    # Trigger database maintenance on all collected tables, then clear the store.
    # In multi-tenant setups call this once after all tenant migrations complete.
    def run!(schema: nil)
      return unless configuration.enabled

      Executor.call(schema:)
    end

    def reset!
      store.reset!
    end

    def store
      @store = nil if @store_key != store_key
      @store_key = store_key
      @store ||= build_store
    end

    private

    def store_key
      [
        configuration.store.to_s,
        configuration.run_id.to_s,
        configuration.store_options_for(configuration.store).hash
      ]
    end

    def build_store
      case configuration.store.to_s
      when 'file'
        file_store
      when 'redis'
        redis_store
      else
        Stores::Memory.new
      end
    end

    def file_store
      options = configuration.store_options_for(:file)
      Stores::FileStore.new(
        path: options.fetch(:path),
        run_id: options.fetch(:run_id, configuration.run_id)
      )
    end

    def redis_store
      options = configuration.store_options_for(:redis)
      Stores::RedisStore.new(
        redis: options[:client],
        key_prefix: options.fetch(:key_prefix),
        run_id: options.fetch(:run_id, configuration.run_id),
        ttl: options.fetch(:ttl)
      )
    end
  end
end
