# frozen_string_literal: true

module AfterMigrate
  module Sql
    IDENT = /
      (?:"\w+"|\w+)
      (?:\.(?:"\w+"|\w+))*
    /x

    PATTERNS = {
      update: /update\s+(?:only\s+)?(#{IDENT})(?!\()/ix,
      insert: /insert\s+into\s+(#{IDENT})(?!\()/ix,
      delete: /delete\s+from\s+(#{IDENT})(?!\()/ix,
      drop_table: /drop\s+table\s+(?:if\s+exists\s+)?(#{IDENT})(?!\()/ix,
      alter_table: /alter\s+table\s+(#{IDENT})(?!\()/ix,
      create_table: /create\s+table\s+(?:if\s+not\s+exists\s+)?(#{IDENT})(?!\()/ix,
      from_join: /(?:from|join)\s+(#{IDENT})(?!\()/ix
    }.freeze

    def parse_tables(sql)
      PATTERNS.flat_map { |_, r| sql.scan(r).flatten }.uniq
    end
  end
end
