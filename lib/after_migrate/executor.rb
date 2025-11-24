# frozen_string_literal: true

require 'after_migrate/adapters/mysql'
require 'after_migrate/adapters/postgresql'
require 'after_migrate/adapters/sqlite'

module AfterMigrate
  module Executor
    extend self

    module_function

    def call(reset: true, schema: nil)
      AfterMigrate.log("Executing schema: #{schema} -> #{target_tables}...")
      return if target_tables.blank?
      return run_optimize(schema:, tables: target_tables[schema]) if schema.present?

      target_tables.each do |s, tables|
        run_optimize(schema: s, tables:)
      end
    ensure
      AfterMigrate::Current.reset if reset
    end

    public :call

    private

    def run_optimize(schema:, tables:)
      table_names = tables.to_a.sort
      return if table_names.empty?

      AfterMigrate.log("Migration touched #{table_names.size} table(s): #{table_names.join(', ')}")
      optimize_tables(schema:, table_names:)
    end

    def optimize_tables(schema:, table_names:)
      connection = ActiveRecord::Base.connection
      adapter = connection.adapter_name
      case adapter
      when 'PostgreSQL'
        AfterMigrate::Postgresql.optimize_tables(schema:, table_names:, connection:)
      when 'SQLite'
        AfterMigrate::Sqlite.optimize_tables(schema:, table_names:, connection:)
      when 'Mysql2', 'Trilogy'
        AfterMigrate::Mysql.optimize_tables(schema:, table_names:, connection:)
      else
        AfterMigrate.log("No maintenance implemented for #{adapter}")
      end
    end

    def target_tables
      case AfterMigrate.configuration.analyze
      when 'all_tables'
        AfterMigrate::Current.affected_tables.each_value do |schema|
          all_tables(schema:)
        end
      when 'only_affected_tables'
        AfterMigrate::Current.affected_tables
      else
        []
      end
    end

    def all_tables(schema:)
      connection = ActiveRecord::Base.connection
      adapter = connection.adapter_name
      case adapter
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
