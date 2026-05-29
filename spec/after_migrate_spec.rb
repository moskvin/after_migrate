# frozen_string_literal: true

describe AfterMigrate do
  after do
    AfterMigrate.reset!
    AfterMigrate.configuration.enabled = true
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
end
