# frozen_string_literal: true

module AfterMigrate
  module Sqlite
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

    def all_tables(**) = []
  end
end
