# frozen_string_literal: true

require 'after_migrate/version'
require 'after_migrate/collector'
require 'after_migrate/executor'
require 'after_migrate/railtie'

module AfterMigrate
  class Configuration
    attr_accessor :enabled, :verbose, :vacuum, :analyze, :rake_tasks_enhanced, :defer

    def initialize
      @enabled = true
      @verbose = true
      @vacuum = true
      @analyze = 'only_affected_tables'
      @rake_tasks_enhanced = true
      @defer = true
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
      @affected_tables ||= Concurrent::Map.new
    end

    def merge_tables(schema, table_names)
      return if table_names.blank?

      set = affected_tables.compute_if_absent(schema) { Concurrent::Set.new }
      set.merge(table_names)
    end

    # Trigger database maintenance on all collected tables, then clear the store.
    # In multi-tenant setups call this once after all tenant migrations complete.
    def run!(schema: nil)
      return unless configuration.enabled

      Executor.call(schema:)
    end

    def reset!
      @affected_tables = nil
    end
  end
end
