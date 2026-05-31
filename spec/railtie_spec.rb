# frozen_string_literal: true

require 'rake'

describe AfterMigrate::Railtie do
  let(:rake_application) { Rake::Application.new }

  around do |example|
    original_application = Rake.application
    Rake.application = rake_application
    example.run
  ensure
    Rake.application = original_application
  end

  before do
    Rake::Task.define_task('db:migrate')
    Rake::Task.define_task('db:migrate:up')
    Rake::Task.define_task('db:migrate:redo')
    Rake::Task.define_task('environment')
    rake_context = Object.new
    rake_context.extend(Rake::DSL)
    described_class.rake_tasks.each { |rake_task| rake_context.instance_eval(&rake_task) }
  end

  after do
    AfterMigrate.configuration.enabled = true
    AfterMigrate.configuration.rake_tasks_enhanced = true
    AfterMigrate.configuration.defer = true
  end

  describe 'enhanced migration tasks' do
    it 'defers automatic maintenance when defer is enabled' do
      AfterMigrate.configuration.defer = true

      expect(AfterMigrate).not_to receive(:run!)

      Rake::Task['db:migrate'].invoke
    end

    it 'runs maintenance after migrations when defer is disabled' do
      AfterMigrate.configuration.defer = false

      expect(AfterMigrate).to receive(:run!)

      Rake::Task['db:migrate'].invoke
    end
  end
end
