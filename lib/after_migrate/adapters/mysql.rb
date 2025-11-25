# frozen_string_literal: true

module AfterMigrate
  module Mysql
    module_function

    def optimize_tables(connection:, table_names:, **)
      table_names.each do |t|
        quoted = connection.quote_table_name(t)
        AfterMigrate.log("ANALYZE TABLE #{quoted}")
        connection.execute("ANALYZE TABLE #{quoted}")
      end
    end

    def all_tables(schema: nil)
      connection = ActiveRecord::Base.connection
      database = schema.to_s.presence || connection.current_database

      connection.select_values(<<~SQL.squish)
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = #{connection.quote(database)}
          AND table_type = 'BASE TABLE'           -- exclude views
          AND table_name NOT LIKE 'ar_internal_metadata'
          AND table_name NOT LIKE 'schema_migrations'
        ORDER BY table_name
      SQL
    end
  end
end
