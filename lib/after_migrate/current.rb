# frozen_string_literal: true

require 'active_support/current_attributes'

module AfterMigrate
  class Current < ActiveSupport::CurrentAttributes
    attribute :affected_tables

    resets do
      self.affected_tables = Hash.new { |h, k| h[k] = Concurrent::Set.new }
    end
  end
end
