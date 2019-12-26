require 'fileutils'
require 'shellwords'

def apply_template!
  add_template_repository_to_source_path
  remove_unwanted_gems
  add_gems
  setup_generators
  setup_databaseyml

  after_bundle do
    # setup rspec
    run 'bundle exec rspec --init'
    copy_file 'spec_rails_helper.rb', 'spec/rails_helper.rb'
    template 'Dockerfile.dev.tt'

    # prepare project structure
    run 'mkdir backend'
    backend_files = Dir.entries('.') - %w[. .. .git backend .gitignore]
    run "mv #{backend_files.join(' ')} -t backend"
    file 'frontend/README.md'
    file 'devops/README.md'

    template 'docker-compose.yml'
    template './Makefile.tt'
    copy_file 'gitignore', '.gitignore', force: true

    git init, first commit
    git :init
    git add: '-- .'
    git commit: "-a -m 'Initial commit'"
  end
end

def add_gems
  gem 'fast_jsonapi'
  gem 'rswag-api'
  gem 'rswag-ui'
  gem 'rails_12factor'
  gem 'tzinfo-data'

  gem_group :development, :test do
    gem 'pry'
    gem 'pry-byebug'
    gem 'pry-rails'
    gem 'awesome_print'
    gem 'rspec-rails'
    gem 'rswag'
    gem 'rswag-specs'
    gem 'factory_bot_rails'
    gem 'database_cleaner'
  end
end

def setup_generators
  environment <<~CODE, env: 'production'
    config.generators do |g|
      g.assets            false
      g.helper            false
      g.javascript_engine :js
      g.orm              :active_record
      g.template_engine  :haml
      g.test_framework   :rspec
      g.stylesheets      false
    end
  CODE
end

def setup_databaseyml
  # run 'rm config/database.yml'
  template 'database.yml.tt', 'config/database.yml', force: true
end

# TODO: bad design, will be better to make own Gemfile template
def remove_unwanted_gems
  %w(coffee-rails jbuilder tzinfo-data byebug).each do |unwanted_gem|
    gsub_file('Gemfile', /gem '#{unwanted_gem}'.*\n/, '')
  end
end

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("rails-template-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/qelphybox/react-rails-template.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{rails-template/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

apply_template!
