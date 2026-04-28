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

      # Unsubscribe when the app starts serving requests so normal web traffic
      # is never collected.
      app.executor.to_run { ActiveSupport::Notifications.unsubscribe(subscription) }
    end

    rake_tasks do
      %w[
        db:migrate
        db:migrate:up
        db:migrate:redo
      ].each do |task_name|
        Rake::Task[task_name].enhance do
          next unless AfterMigrate.configuration.enabled
          next unless AfterMigrate.configuration.rake_tasks_enhanced
          next if AfterMigrate.configuration.defer

          AfterMigrate.run!
        end
      end

      namespace :after_migrate do
        desc 'Run database maintenance (ANALYZE/VACUUM) on all tables collected across migrations'
        task run: :environment do
          AfterMigrate.run!
        end
      end
    end
  end
end
