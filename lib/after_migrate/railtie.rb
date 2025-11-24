# frozen_string_literal: true

require 'rails'
require 'active_support/notifications'

module AfterMigrate
  class Railtie < ::Rails::Railtie
    initializer 'after_migrate.subscribe' do |app|
      next unless AfterMigrate.configuration.enabled

      subscription = ActiveSupport::Notifications.subscribe 'sql.active_record' do |*args|
        AfterMigrate::Collector.call(*args)
      end

      app.executor.to_run { ActiveSupport::Notifications.unsubscribe(subscription) }
    end

    rake_tasks do
      next unless AfterMigrate.configuration.enabled
      next unless AfterMigrate.configuration.rake_tasks_enhanced

      %w[
        db:migrate
        db:migrate:up
        db:migrate:redo
      ].each do |task_name|
        Rake::Task[task_name].enhance do
          AfterMigrate::Executor.call(reset: true)
        end
      end
    end
  end
end
