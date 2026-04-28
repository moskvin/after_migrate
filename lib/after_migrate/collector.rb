# frozen_string_literal: true

module AfterMigrate
  module Collector
    extend self

    module_function

    def call(*)
      event = ActiveSupport::Notifications::Event.new(*)
      sql = event.payload[:sql]&.strip
      return unless sql
      return unless sql.match?(/\A\s*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|RENAME\s+TABLE|TRUNCATE)/i)

      table_names = parse_tables(sql)
      schema = fetch_schema
      AfterMigrate.merge_tables(schema, table_names)
    end

    private

    def fetch_schema
      connection = ActiveRecord::Base.connection
      case connection.adapter_name
      when 'PostgreSQL'
        quoted = connection.schema_search_path.split(',').first
        quoted&.delete('"')
      end
    end

    def parse_tables(sql)
      connection = ActiveRecord::Base.connection
      case connection.adapter_name
      when 'PostgreSQL'
        AfterMigrate::Postgresql.parse_tables(sql)
      when 'SQLite'
        AfterMigrate::Sqlite.parse_tables(sql)
      when 'Mysql2', 'Trilogy'
        AfterMigrate::Mysql.parse_tables(sql)
      else
        AfterMigrate.log("No maintenance implemented for #{connection.adapter_name}")
      end
    end
  end
end
