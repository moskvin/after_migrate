# frozen_string_literal: true

require 'pg_query'

module AfterMigrate
  module Postgresql
    extend Sql

    module_function

    def vacuum(table_name, schema: nil, verbose: true)
      table = ActiveRecord::Base.connection.quote_table_name("#{schema}.#{table_name}")
      query = <<~SQL.squish
        VACUUM (#{'VERBOSE, ' if verbose}ANALYZE, INDEX_CLEANUP ON) #{table};
      SQL

      ActiveRecord::Base.connection.execute(query)
    end

    def dead_tuples(schema: nil, table: nil, sort: nil)
      allowed_sorts = %w[schemaname relname n_dead_tup n_live_tup dead_tuple_ratio autovacuum_count]
      sort = 'dead_tuple_ratio' unless allowed_sorts.include?(sort)
      query = <<~SQL.squish
        SELECT
          schemaname,
          relname,
          last_vacuum,
          last_autovacuum,
          vacuum_count,
          autovacuum_count,
          n_dead_tup,
          n_live_tup,
          (COALESCE(n_dead_tup, 0)::numeric / GREATEST(COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0), 1)::numeric) AS dead_tuple_ratio
        FROM pg_stat_all_tables
        WHERE COALESCE(n_dead_tup, 0) > 0
        #{"AND schemaname = #{ActiveRecord::Base.connection.quote(schema)}" if schema}
        #{"AND relname = #{ActiveRecord::Base.connection.quote(table)}" if table}
        ORDER BY #{sort} DESC NULLS LAST;
      SQL

      ActiveRecord::Base.connection.execute(query)
    end

    def run_vacuum(schema:)
      tables_with_dead_tuples = dead_tuples(schema:).pluck('relname')
      AfterMigrate.log("Vacuuming #{tables_with_dead_tuples.size} tables in schema #{schema}...")
      tables_with_dead_tuples.each { |t| vacuum(t) }
      tables_with_dead_tuples
    end

    def run_analyze(schema:, tables:)
      connection = ActiveRecord::Base.connection
      tables.each do |t|
        table = if t.include?('.')
                  connection.quote_table_name(t)
                else
                  connection.quote_table_name("#{schema}.#{t}")
                end
        AfterMigrate.log("ANALYZE VERBOSE #{table}")
        connection.execute("ANALYZE#{AfterMigrate.configuration.verbose ? ' VERBOSE ' : ' '}#{table}")
      end
    end

    def optimize_tables(table_names:, schema:, **)
      cleaned_tables = []
      cleaned_tables = run_vacuum(schema:) if AfterMigrate.configuration.vacuum

      tables = table_names - cleaned_tables
      run_analyze(schema:, tables:)
    end

    def all_tables(schema: nil)
      connection = ActiveRecord::Base.connection
      schema_value = schema ? schema.to_s.strip : 'public'

      query = <<~SQL.squish
        SELECT c.relname AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = #{connection.quote(schema_value)}
          AND c.relkind IN ('r', 'p')        -- ordinary tables + partitioned tables
          AND c.relispartition = FALSE      -- exclude partition child tables
        ORDER BY table_name
      SQL

      connection.select_values(query)
    end

    def parse_tables(sql)
      PgQuery.parse(sql).tables
    end
  end
end
