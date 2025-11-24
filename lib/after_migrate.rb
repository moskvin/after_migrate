# frozen_string_literal: true

require 'after_migrate/version'
require 'after_migrate/current'
require 'after_migrate/collector'
require 'after_migrate/executor'
require 'after_migrate/railtie'

module AfterMigrate
  class Configuration
    attr_accessor :enabled, :verbose, :vacuum, :analyze, :rake_tasks_enhanced

    def initialize
      @enabled = true
      @verbose = true
      @vacuum = true
      @analyze = 'only_affected_tables'
      @rake_tasks_enhanced = true
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def log(msg)
      warn "[after_migrate] #{msg}" if AfterMigrate.configuration.verbose
    end
  end
end
