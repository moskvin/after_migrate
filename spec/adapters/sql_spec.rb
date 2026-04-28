# frozen_string_literal: true

# Tests the shared Sql regex parser used by MySQL and SQLite adapters.
# PostgreSQL uses pg_query instead (see postgresql adapter).
describe AfterMigrate::Sql do
  subject(:parser) { Module.new { extend AfterMigrate::Sql } }

  describe '#parse_tables' do
    context 'CREATE TABLE' do
      it { expect(parser.parse_tables('CREATE TABLE users (id int)')).to include('users') }
      it { expect(parser.parse_tables('CREATE TABLE IF NOT EXISTS users (id int)')).to include('users') }
      it { expect(parser.parse_tables('CREATE TABLE public.users (id int)')).to include('public.users') }
    end

    context 'ALTER TABLE' do
      it { expect(parser.parse_tables('ALTER TABLE users ADD COLUMN name varchar')).to include('users') }
      it { expect(parser.parse_tables('ALTER TABLE "public"."orders" DROP COLUMN x')).to include('"public"."orders"') }
    end

    context 'DROP TABLE' do
      it { expect(parser.parse_tables('DROP TABLE users')).to include('users') }
      it { expect(parser.parse_tables('DROP TABLE IF EXISTS users')).to include('users') }
    end

    context 'INSERT INTO' do
      it { expect(parser.parse_tables('INSERT INTO users VALUES (1)')).to include('users') }
    end

    context 'UPDATE' do
      it { expect(parser.parse_tables('UPDATE users SET name = "foo"')).to include('users') }
      it { expect(parser.parse_tables('UPDATE ONLY users SET x = 1')).to include('users') }
    end

    context 'DELETE FROM' do
      it { expect(parser.parse_tables('DELETE FROM users WHERE id = 1')).to include('users') }
    end

    context 'deduplication' do
      it 'returns each table name once even when matched by multiple patterns' do
        sql = 'INSERT INTO users SELECT * FROM users'
        expect(parser.parse_tables(sql).count { |t| t == 'users' }).to eq(1)
      end
    end

    context 'no false positives' do
      it 'does not capture function calls as table names' do
        # generate_series is followed by ( so the negative lookahead suppresses it
        expect(parser.parse_tables('INSERT INTO events SELECT generate_series(1,10)')).not_to include('generate_series')
      end

      it 'does not capture subquery aliases' do
        expect(parser.parse_tables('UPDATE users SET x = (SELECT 1)')).to eq(['users'])
      end
    end
  end
end
