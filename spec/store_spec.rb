# frozen_string_literal: true

describe AfterMigrate::Stores::Memory do
  subject(:store) { described_class.new }

  describe '#merge_tables' do
    it 'accumulates table names per schema' do
      store.merge_tables('public', %w[users posts])
      store.merge_tables('public', ['comments'])

      expect(store.affected_tables['public'].to_a).to match_array(%w[users posts comments])
    end

    it 'keeps schemas isolated' do
      store.merge_tables('tenant_a', ['orders'])
      store.merge_tables('tenant_b', ['orders'])

      expect(store.affected_tables.keys).to match_array(%w[tenant_a tenant_b])
    end

    it 'ignores blank table names' do
      store.merge_tables('public', [])

      expect(store.affected_tables).to be_empty
    end
  end

  describe '#reset!' do
    it 'clears the affected table map' do
      store.merge_tables('public', ['users'])

      store.reset!

      expect(store.affected_tables).to be_empty
    end
  end
end

describe AfterMigrate::Stores::FileStore do
  subject(:store) { described_class.new(path:, run_id:) }

  let(:path) { File.join(Dir.tmpdir, "after_migrate-#{SecureRandom.hex}.json") }
  let(:run_id) { 'test-run' }

  after do
    FileUtils.rm_f(path)
    FileUtils.rm_f("#{path}.lock")
  end

  it 'persists tables across store instances' do
    store.merge_tables('public', %w[users posts])

    fresh_store = described_class.new(path:, run_id:)

    expect(fresh_store.affected_tables['public'].to_a).to match_array(%w[posts users])
  end

  it 'merges persisted tables instead of overwriting them' do
    store.merge_tables('public', ['users'])
    store.merge_tables('public', ['posts'])

    expect(store.affected_tables['public'].to_a).to match_array(%w[posts users])
  end

  it 'ignores persisted tables from a different run id' do
    store.merge_tables('public', ['users'])

    other_store = described_class.new(path:, run_id: 'other-run')

    expect(other_store.affected_tables).to be_empty
  end

  it 'ignores an invalid persisted file' do
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, '{invalid json')

    expect(store.affected_tables).to be_empty
  end

  it 'removes the persisted file on reset' do
    store.merge_tables('public', ['users'])

    store.reset!

    expect(File.exist?(path)).to be(false)
  end
end
