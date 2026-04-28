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
      tables = target_tables
      return if tables.blank?

      if schema.present?
        run_optimize(schema:, tables: tables[schema]) if tables[schema].present?
      else
        tables.each { |s, t| run_optimize(schema: s, tables: t) }
      end
    ensure
      AfterMigrate.reset!
    end

    public :call

    private

    def run_optimize(schema:, tables:)
      table_names = tables.to_a.sort
      return if table_names.empty?

      AfterMigrate.log("Migration touched #{table_names.size} table(s) in schema #{schema.inspect}: #{table_names.join(', ')}")
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
      when 'only_affected_tables'
        AfterMigrate.affected_tables
      else
        {}
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
