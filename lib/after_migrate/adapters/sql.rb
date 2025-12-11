# frozen_string_literal: true

module AfterMigrate
  module Sql
    IDENT = /
      (?:"[\w]+"|\w+)
      (?:\.(?:"[\w]+"|\w+))*
    /x

    PATTERNS = {
      update: /update\s+(?:only\s+)?(#{IDENT})(?!\s*\()/ix,
      insert: /insert\s+into\s+(#{IDENT})(?!\s*\()/ix,
      delete: /delete\s+from\s+(#{IDENT})(?!\s*\()/ix,
      drop_table: /drop\s+table\s+(?:if\s+exists\s+)?(#{IDENT})(?!\s*\()/ix,
      alter_table: /alter\s+table\s+(#{IDENT})(?!\s*\()/ix,
      create_table: /create\s+table\s+(?:if\s+not\s+exists\s+)?(#{IDENT})(?!\s*\()/ix,
      from_join: /(?:from|join)\s+(#{IDENT})(?!\s*\()/ix
    }.freeze

    def parse_tables(sql)
      PATTERNS.flat_map { |_, r| sql.scan(r).flatten }.uniq
    end
  end
end
