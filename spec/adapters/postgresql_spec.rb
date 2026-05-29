# frozen_string_literal: true

describe AfterMigrate::Postgresql do
  let(:connection) { double('connection', adapter_name: 'PostgreSQL') }

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    allow(connection).to receive(:quote_table_name) { |t| %("#{t}") }
    allow(connection).to receive(:quote) { |v| "'#{v}'" }
  end

  after do
    AfterMigrate.reset!
    AfterMigrate.configuration.vacuum = true
    AfterMigrate.configuration.analyze = 'only_affected_tables'
    AfterMigrate.configuration.verbose = true
  end

  describe '.optimize_tables' do
    let(:dead_tuples_relation) { double('rel', pluck: %w[posts users orders]) }

    context 'when vacuum=false and analyze=only_affected_tables' do
      before do
        AfterMigrate.configuration.vacuum = false
        AfterMigrate.configuration.analyze = 'only_affected_tables'
      end

      it 'runs ANALYZE but never queries pg_stat_all_tables (no VACUUM path)' do
        expect(described_class).not_to receive(:dead_tuples)
        expect(described_class).to receive(:run_analyze)
          .with(schema: 'public', tables: %w[posts users])
        described_class.optimize_tables(schema: 'public', table_names: %w[posts users])
      end
    end

    context 'when vacuum=true and analyze=none' do
      before do
        AfterMigrate.configuration.vacuum = true
        AfterMigrate.configuration.analyze = 'none'
        allow(described_class).to receive(:dead_tuples).and_return(dead_tuples_relation)
        allow(described_class).to receive(:vacuum)
      end

      it 'runs VACUUM and skips ANALYZE' do
        expect(described_class).not_to receive(:run_analyze)
        described_class.optimize_tables(schema: 'public', table_names: %w[posts users])
      end
    end

    context 'when both vacuum and analyze run' do
      before do
        AfterMigrate.configuration.vacuum = true
        AfterMigrate.configuration.analyze = 'only_affected_tables'
        allow(described_class).to receive(:dead_tuples).and_return(dead_tuples_relation)
        allow(described_class).to receive(:vacuum)
      end

      it 'does not re-analyze tables that VACUUM already covered' do
        # dead_tuples = posts, users, orders; affected = posts, users → vacuum hits posts+users
        # run_analyze should then get the difference (empty)
        expect(described_class).to receive(:run_analyze)
          .with(schema: 'public', tables: [])
        described_class.optimize_tables(schema: 'public', table_names: %w[posts users])
      end
    end
  end

  describe '.run_vacuum' do
    let(:dead_tuples_relation) { double('rel', pluck: %w[posts users orders comments]) }

    before do
      allow(described_class).to receive(:dead_tuples).with(schema: 'public').and_return(dead_tuples_relation)
    end

    it 'only vacuums tables present in both dead_tuples and table_names' do
      expect(described_class).to receive(:vacuum)
        .with('posts', schema: 'public', verbose: true).ordered
      expect(described_class).to receive(:vacuum)
        .with('users', schema: 'public', verbose: true).ordered
      expect(described_class).not_to receive(:vacuum).with('orders', any_args)
      expect(described_class).not_to receive(:vacuum).with('comments', any_args)

      result = described_class.run_vacuum(schema: 'public', table_names: %w[posts users missing])
      expect(result).to eq(%w[posts users])
    end

    it 'falls back to all dead-tuple tables when table_names is nil (backward compat)' do
      expect(described_class).to receive(:vacuum).exactly(4).times
      described_class.run_vacuum(schema: 'public')
    end

    it 'propagates configuration.verbose to vacuum' do
      AfterMigrate.configuration.verbose = false
      expect(described_class).to receive(:vacuum)
        .with('posts', schema: 'public', verbose: false)
      described_class.run_vacuum(schema: 'public', table_names: %w[posts])
    end
  end

  describe '.vacuum' do
    it 'qualifies the table with schema when schema is present' do
      expect(connection).to receive(:quote_table_name).with('public.posts').and_return('"public.posts"')
      expect(connection).to receive(:execute).with(/VACUUM .* "public.posts";/)
      described_class.vacuum('posts', schema: 'public')
    end

    it 'uses the bare table name when schema is nil (no leading dot bug)' do
      expect(connection).to receive(:quote_table_name).with('posts').and_return('"posts"')
      expect(connection).to receive(:execute).with(/VACUUM .* "posts";/)
      described_class.vacuum('posts', schema: nil)
    end
  end
end
