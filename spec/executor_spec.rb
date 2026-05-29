# frozen_string_literal: true

describe AfterMigrate::Executor do
  let(:connection) { double('connection', adapter_name: 'PostgreSQL') }

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    AfterMigrate.merge_tables('public', %w[users posts])
  end

  after do
    AfterMigrate.reset!
    AfterMigrate.configuration.analyze = 'only_affected_tables'
    AfterMigrate.configuration.vacuum = true
  end

  describe '.call' do
    context 'analyze: only_affected_tables (default)' do
      before { allow(AfterMigrate::Postgresql).to receive(:optimize_tables) }

      it 'passes the sorted collected tables to the adapter' do
        expect(AfterMigrate::Postgresql).to receive(:optimize_tables)
          .with(schema: 'public', table_names: %w[posts users], connection: connection)
        AfterMigrate::Executor.call
      end

      it 'resets the store after execution' do
        AfterMigrate::Executor.call
        expect(AfterMigrate.affected_tables).to be_empty
      end
    end

    context 'analyze: all_tables' do
      before do
        AfterMigrate.configuration.analyze = 'all_tables'
        allow(AfterMigrate::Postgresql).to receive(:all_tables).with(schema: 'public')
          .and_return(%w[comments posts users])
      end

      it 'passes the full table list for each affected schema to the adapter' do
        expect(AfterMigrate::Postgresql).to receive(:optimize_tables)
          .with(schema: 'public', table_names: %w[comments posts users], connection: connection)
        AfterMigrate::Executor.call
      end
    end

    context 'analyze: none' do
      before { AfterMigrate.configuration.analyze = 'none' }

      context 'and vacuum: false' do
        before { AfterMigrate.configuration.vacuum = false }

        it 'does not call optimize_tables' do
          expect(AfterMigrate::Postgresql).not_to receive(:optimize_tables)
          AfterMigrate::Executor.call
        end

        it 'still resets the store' do
          AfterMigrate::Executor.call
          expect(AfterMigrate.affected_tables).to be_empty
        end
      end

      context 'and vacuum: true' do
        before do
          AfterMigrate.configuration.vacuum = true
          allow(AfterMigrate::Postgresql).to receive(:optimize_tables)
        end

        it 'still calls optimize_tables so the adapter can vacuum' do
          expect(AfterMigrate::Postgresql).to receive(:optimize_tables)
            .with(schema: 'public', table_names: %w[posts users], connection: connection)
          AfterMigrate::Executor.call
        end

        it 'resets the store' do
          AfterMigrate::Executor.call
          expect(AfterMigrate.affected_tables).to be_empty
        end
      end
    end

    context 'with schema: argument' do
      before do
        AfterMigrate.merge_tables('tenant_b', ['orders'])
        allow(AfterMigrate::Postgresql).to receive(:optimize_tables)
      end

      it 'only processes the specified schema' do
        expect(AfterMigrate::Postgresql).to receive(:optimize_tables)
          .with(hash_including(schema: 'public')).once
        AfterMigrate::Executor.call(schema: 'public')
      end

      it 'resets the full store, not just the targeted schema' do
        AfterMigrate::Executor.call(schema: 'public')
        expect(AfterMigrate.affected_tables).to be_empty
      end
    end

    context 'when the store is empty' do
      before { AfterMigrate.reset! }

      it 'does not call optimize_tables' do
        expect(AfterMigrate::Postgresql).not_to receive(:optimize_tables)
        AfterMigrate::Executor.call
      end
    end

    context 'when optimize_tables raises' do
      before do
        allow(AfterMigrate::Postgresql).to receive(:optimize_tables).and_raise(StandardError, 'DB error')
      end

      it 'still resets the store via ensure' do
        expect { AfterMigrate::Executor.call }.to raise_error(StandardError, 'DB error')
        expect(AfterMigrate.affected_tables).to be_empty
      end
    end
  end
end
