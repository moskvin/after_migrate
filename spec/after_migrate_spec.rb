# frozen_string_literal: true

describe AfterMigrate do
  after do
    AfterMigrate.configuration.enabled = true
    AfterMigrate.configuration.store = :memory
    AfterMigrate.configuration.run_id = 'default'
    AfterMigrate.configuration.store_options = {
      file: {
        path: 'tmp/after_migrate/affected_tables.json'
      },
      redis: {
        client: nil,
        key_prefix: 'after_migrate',
        ttl: 24 * 60 * 60
      }
    }
    AfterMigrate.instance_variable_set(:@store, nil)
    AfterMigrate.instance_variable_set(:@store_key, nil)
    AfterMigrate.reset!
  end

  describe '.run!' do
    context 'when enabled' do
      before { AfterMigrate.configuration.enabled = true }

      it 'calls Executor' do
        expect(AfterMigrate::Executor).to receive(:call).with(schema: nil)
        AfterMigrate.run!
      end

      it 'forwards the schema keyword' do
        expect(AfterMigrate::Executor).to receive(:call).with(schema: 'tenant_42')
        AfterMigrate.run!(schema: 'tenant_42')
      end
    end

    context 'when disabled' do
      before { AfterMigrate.configuration.enabled = false }

      it 'does not call Executor' do
        expect(AfterMigrate::Executor).not_to receive(:call)
        AfterMigrate.run!
      end

      it 'returns nil' do
        expect(AfterMigrate.run!).to be_nil
      end
    end
  end

  describe '.affected_tables' do
    it 'returns a Concurrent::Map' do
      expect(AfterMigrate.affected_tables).to be_a(Concurrent::Map)
    end

    it 'uses the configured store object' do
      expect(AfterMigrate.store).to receive(:affected_tables).and_call_original
      AfterMigrate.affected_tables
    end

    it 'is reset to a fresh map after reset!' do
      AfterMigrate.merge_tables('public', ['users'])
      AfterMigrate.reset!
      expect(AfterMigrate.affected_tables).to be_empty
    end
  end

  describe '.merge_tables' do
    it 'accumulates table names per schema' do
      AfterMigrate.merge_tables('public', %w[users posts])
      AfterMigrate.merge_tables('public', ['comments'])
      expect(AfterMigrate.affected_tables['public'].to_a).to match_array(%w[users posts comments])
    end

    it 'keeps schemas isolated' do
      AfterMigrate.merge_tables('tenant_a', ['orders'])
      AfterMigrate.merge_tables('tenant_b', ['orders'])
      expect(AfterMigrate.affected_tables.keys).to match_array(%w[tenant_a tenant_b])
    end

    it 'ignores blank table_names' do
      AfterMigrate.merge_tables('public', [])
      expect(AfterMigrate.affected_tables).to be_empty
    end
  end

  describe '.store' do
    it 'defaults to the memory store' do
      expect(AfterMigrate.store).to be_a(AfterMigrate::Stores::Memory)
    end

    it 'uses a file store when configured' do
      AfterMigrate.configuration.store = :file
      AfterMigrate.configuration.store_options_for(:file)[:path] = '/tmp/after_migrate-test.json'

      expect(AfterMigrate.store).to be_a(AfterMigrate::Stores::FileStore)
    end

    it 'uses a redis store when configured' do
      AfterMigrate.configuration.store = :redis
      AfterMigrate.configuration.store_options_for(:redis)[:client] = Object.new

      expect(AfterMigrate.store).to be_a(AfterMigrate::Stores::RedisStore)
    end
  end

  describe 'store option compatibility accessors' do
    it 'maps file accessors to file store options' do
      AfterMigrate.configuration.store_path = '/tmp/after-migrate.json'

      expect(AfterMigrate.configuration.store_options_for(:file)[:path]).to eq('/tmp/after-migrate.json')
      expect(AfterMigrate.configuration.store_path).to eq('/tmp/after-migrate.json')
    end

    it 'maps redis accessors to redis store options' do
      client = Object.new

      AfterMigrate.configuration.redis = client
      AfterMigrate.configuration.redis_key_prefix = 'custom'
      AfterMigrate.configuration.redis_ttl = 10

      expect(AfterMigrate.configuration.store_options_for(:redis)).to include(
        client: client,
        key_prefix: 'custom',
        ttl: 10
      )
    end
  end
end
