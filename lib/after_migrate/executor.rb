# frozen_string_literal: true

require 'after_migrate/adapters/sql'
require 'after_migrate/adapters/mysql'
require 'after_migrate/adapters/postgresql'
require 'after_migrate/adapters/sqlite'

module AfterMigrate
  module Executor
    extend self

    module_function

    def call(schema: nil)
      return reset_store unless maintenance_enabled?

      tables = target_tables
      return reset_store if tables.blank?

      run_optimizations(schema:, tables:)
      reset_store
    end

    public :call

    private

    def maintenance_enabled?
      AfterMigrate.configuration.vacuum || AfterMigrate.configuration.analyze != 'none'
    end

    def reset_store
      AfterMigrate.reset!
    end

    def run_optimizations(schema:, tables:)
      return run_optimize(schema:, tables: tables[schema]) if schema.present? && tables[schema].present?

      tables.each { |s, t| run_optimize(schema: s, tables: t) } unless schema.present?
    end

    def run_optimize(schema:, tables:)
      table_names = tables.to_a.sort
      return if table_names.empty?

      message = "Migration touched #{table_names.size} table(s) in schema #{schema.inspect}: #{table_names.join(', ')}"
      AfterMigrate.log(message)
      optimize_tables(schema:, table_names:)
    end

    def optimize_tables(schema:, table_names:)
      connection = ActiveRecord::Base.connection
      case connection.adapter_name
      when 'PostgreSQL'
        AfterMigrate::Postgresql.optimize_tables(schema:, table_names:, connection:)
      when 'SQLite'
        AfterMigrate::Sqlite.optimize_tables(schema:, table_names:, connection:)
      when 'Mysql2', 'Trilogy'
        AfterMigrate::Mysql.optimize_tables(schema:, table_names:, connection:)
      else
        AfterMigrate.log("No maintenance implemented for #{connection.adapter_name}")
      end
    end

    def target_tables
      case AfterMigrate.configuration.analyze
      when 'all_tables'
        AfterMigrate.affected_tables.keys.each_with_object({}) do |schema, hash|
          hash[schema] = all_tables(schema:)
        end
      else
        # 'only_affected_tables' or 'none' — vacuum still needs the affected list
        AfterMigrate.affected_tables
      end
    end

    def all_tables(schema:)
      connection = ActiveRecord::Base.connection
      case connection.adapter_name
      when 'PostgreSQL'
        AfterMigrate::Postgresql.all_tables(schema:)
      when 'SQLite'
        AfterMigrate::Sqlite.all_tables(schema:)
      when 'Mysql2', 'Trilogy'
        AfterMigrate::Mysql.all_tables(schema:)
      else
        []
      end
    end
  end
end
