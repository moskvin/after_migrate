# frozen_string_literal: true

require 'after_migrate/version'
require 'after_migrate/store'
require 'after_migrate/collector'
require 'after_migrate/executor'
require 'after_migrate/railtie'

module AfterMigrate
  class Configuration
    attr_accessor :enabled, :verbose, :vacuum, :analyze, :rake_tasks_enhanced, :defer, :store, :store_path, :run_id

    def initialize
      @enabled = true
      @verbose = true
      @vacuum = true
      @analyze = 'only_affected_tables'
      @rake_tasks_enhanced = true
      @defer = true
      @store = :memory
      @store_path = 'tmp/after_migrate/affected_tables.json'
      @run_id = nil
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
      key = [configuration.store.to_s, configuration.store_path.to_s, configuration.run_id.to_s]
      @store = nil if @store_key != key
      @store_key = key
      @store ||= build_store
    end

    private

    def build_store
      case configuration.store.to_s
      when 'file'
        Stores::FileStore.new(path: configuration.store_path, run_id: configuration.run_id)
      else
        Stores::Memory.new
      end
    end
  end
end
