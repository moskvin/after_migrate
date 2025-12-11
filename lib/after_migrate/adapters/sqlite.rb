# frozen_string_literal: true

module AfterMigrate
  module Sqlite
    extend Sql

    module_function

    def optimize_tables(connection:, **)
      version = connection.respond_to?(:sqlite_version) ? connection.sqlite_version : '0'
      if Gem::Version.new(version.split.first || '0') >= Gem::Version.new('3.35.0')
        AfterMigrate.log('Running PRAGMA optimize')
        connection.execute('PRAGMA optimize;')
      else
        AfterMigrate.log('Running VACUUM; ANALYZE;')
        connection.execute('VACUUM;')
        connection.execute('ANALYZE;')
      end
    end

    def all_tables(**)
      # SQLite has no concept of schema (everything is in one file)
      # The `schema:` parameter is ignored — there's only one database
      ActiveRecord::Base.connection.select_values(<<~SQL.squish)
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
          AND name NOT IN ('ar_internal_metadata', 'schema_migrations')
        ORDER BY name
      SQL
    end
  end
end
