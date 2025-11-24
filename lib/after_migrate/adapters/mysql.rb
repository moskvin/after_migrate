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

    def all_tables(**) = []
  end
end
