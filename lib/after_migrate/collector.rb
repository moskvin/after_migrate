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
      schema ||= fetch_schema
      # AfterMigrate.log("[#{schema}] Detected change from '#{sql}' to tables: #{table_names}") if table_names.present?
      collect_tables(schema:, table_names:)
    end

    private

    def collect_tables(schema:, table_names:)
      return if table_names.blank?

      AfterMigrate::Current.affected_tables ||= Hash.new { |h, k| h[k] = Concurrent::Set.new }
      AfterMigrate::Current.affected_tables[schema].merge(table_names)
    end

    def fetch_schema
      connection = ActiveRecord::Base.connection
      adapter = connection.adapter_name
      case adapter
      when 'PostgreSQL'
        quoted = connection.schema_search_path.split(',').first
        quoted&.delete('"')
      end
    end

    def parse_tables(sql)
      connection = ActiveRecord::Base.connection
      adapter = connection.adapter_name
      case adapter
      when 'PostgreSQL'
        AfterMigrate::Postgresql.parse_tables(sql)
      when 'SQLite'
        AfterMigrate::Sqlite.parse_tables(sql)
      when 'Mysql2', 'Trilogy'
        AfterMigrate::Mysql.parse_tables(sql)
      else
        AfterMigrate.log("No maintenance implemented for #{adapter}")
      end
    end
  end
end
