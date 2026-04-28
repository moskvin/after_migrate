# frozen_string_literal: true

describe AfterMigrate::Collector do
  let(:connection) { double('connection', adapter_name: 'PostgreSQL', schema_search_path: '"public"') }

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    allow(AfterMigrate::Postgresql).to receive(:parse_tables).and_return(['users'])
  end

  after { AfterMigrate.reset! }

  def notify(sql)
    AfterMigrate::Collector.call(
      'sql.active_record', Process.clock_gettime(Process::CLOCK_MONOTONIC),
      Process.clock_gettime(Process::CLOCK_MONOTONIC), SecureRandom.hex(8),
      { sql: sql }
    )
  end

  describe '.call' do
    context 'SQL filtering' do
      it 'ignores SELECT statements' do
        notify('SELECT * FROM users')
        expect(AfterMigrate.affected_tables).to be_empty
      end

      it 'ignores SHOW statements' do
        notify('SHOW search_path')
        expect(AfterMigrate.affected_tables).to be_empty
      end

      it 'ignores nil SQL' do
        AfterMigrate::Collector.call(
          'sql.active_record', Time.now, Time.now, 'x', { sql: nil }
        )
        expect(AfterMigrate.affected_tables).to be_empty
      end

      %w[CREATE ALTER DROP INSERT UPDATE DELETE TRUNCATE].each do |keyword|
        it "collects tables for #{keyword} statements" do
          notify("#{keyword} TABLE users")
          expect(AfterMigrate.affected_tables).not_to be_empty
        end
      end
    end

    context 'schema detection (PostgreSQL)' do
      it 'stores tables under the current search_path schema' do
        notify('CREATE TABLE users (id int)')
        expect(AfterMigrate.affected_tables['public']).to include('users')
      end

      it 'strips surrounding quotes from the schema name' do
        allow(connection).to receive(:schema_search_path).and_return('"tenant_42", public')
        notify('CREATE TABLE orders (id int)')
        expect(AfterMigrate.affected_tables.key?('tenant_42')).to be true
      end
    end

    context 'adapter dispatch' do
      it 'routes to Sqlite parser for SQLite adapter' do
        allow(connection).to receive(:adapter_name).and_return('SQLite')
        expect(AfterMigrate::Sqlite).to receive(:parse_tables).and_return(['items'])
        notify('CREATE TABLE items (id int)')
      end

      it 'routes to Mysql parser for Mysql2 adapter' do
        allow(connection).to receive(:adapter_name).and_return('Mysql2')
        expect(AfterMigrate::Mysql).to receive(:parse_tables).and_return(['items'])
        notify('CREATE TABLE items (id int)')
      end

      it 'routes to Mysql parser for Trilogy adapter' do
        allow(connection).to receive(:adapter_name).and_return('Trilogy')
        expect(AfterMigrate::Mysql).to receive(:parse_tables).and_return(['items'])
        notify('CREATE TABLE items (id int)')
      end

      it 'logs a warning for unknown adapters and does not raise' do
        allow(connection).to receive(:adapter_name).and_return('UnknownDB')
        expect(AfterMigrate).to receive(:log).with(/UnknownDB/)
        expect { notify('CREATE TABLE items (id int)') }.not_to raise_error
      end
    end
  end
end
