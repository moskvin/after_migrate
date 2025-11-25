# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'after_migrate/version'

Gem::Specification.new do |spec|
  spec.name          = 'after_migrate'
  spec.version       = AfterMigrate::VERSION
  spec.authors       = ['Nikolay Moskvin']
  spec.email         = ['nikolay.moskvin@gmail.com']

  spec.summary       = 'Automatically ANALYZE and VACUUM tables touched during Rails migrations.'
  spec.description = <<~DESC
    Runs database maintenance (ANALYZE, VACUUM, PRAGMA optimize) on exactly the tables
    created or modified during `rails db:migrate`. Keeps query planner statistics fresh
    and prevents fragmentation after every schema change - automatically.
  DESC
  spec.homepage = 'https://github.com/moskvin/after_migrate'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/moskvin/after_migrate'
    spec.metadata['changelog_uri'] = 'https://github.com/moskvin/after_migrate/blob/master/CHANGELOG.md'
    spec.metadata['rubygems_mfa_required'] = 'true'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rails', '>= 7.0'
end
