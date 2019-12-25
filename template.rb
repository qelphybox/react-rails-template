gem 'fast_jsonapi'
gem 'rswag-api'
gem 'rswag-ui'
gem 'haml-rails'

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

file 'config/database.yml', <<~CODE
  default: &default
    adapter: postgresql
    encoding: unicode
    host: db
    username: postgres
    password:
    pool: 5

  development:
    <<: *default
    database: #{app_name}_development

  test:
    <<: *default
    database: #{app_name}_test
CODE

after_bundle do
  run 'bundle exec rspec --init'

  file 'spec/rails_helper.rb', <<~CODE
    ENV['RAILS_ENV'] ||= 'test'
    require 'spec_helper'
    require File.expand_path('../../config/environment', __FILE__)
    require 'rspec/rails'
    require 'database_cleaner'

    Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
    ActiveRecord::Migration.maintain_test_schema!

    RSpec.configure do |config|
      config.use_transactional_fixtures = false
      config.include FactoryGirl::Syntax::Methods

      config.before(:suite) do
        DatabaseCleaner.clean_with(:truncation)
      end

      config.before(:each) do
        DatabaseCleaner.strategy = :transaction
      end

      config.before(:each, js: true) do
        DatabaseCleaner.strategy = :truncation
      end

      config.before(:each) do
        DatabaseCleaner.start
      end

      config.after(:each) do
        DatabaseCleaner.clean
      end

      config.before(:all) do
        DatabaseCleaner.start
      end

      config.after(:all) do
        DatabaseCleaner.clean
      end

      config.infer_spec_type_from_file_location!
    end
  CODE

  file 'Dockerfile.dev', <<~CODE
    FROM ruby:#{RUBY_VERSION}-alpine

    ENV PROJECT_ROOT=/app
    WORKDIR $PROJECT_ROOT

    RUN apk update && \
        apk add -u --no-cache --progress \
        build-base cmake less \
        postgresql-dev postgresql-client openssh git make

    COPY Gemfile* $PROJECT_ROOT/
    RUN bundle check || BUNDLE_FORCE_RUBY_PLATFORM=1 bundle install --jobs 4 --retry 4
  CODE

  file 'Dockerdev'

  run 'mkdir backend'
  backend_files = Dir.entries('.') - %w[. .. .git backend .gitignore]
  run "mv #{backend_files.join(' ')} -t backend"
  file 'frontend/README.md'
  file 'devops/README.md'

  file 'docker-compose.yml', <<~YAML
    version: '3'

    services:
      db:
        image: postgres:12-alpine
        environment:
          PGPASSWORD_SUPERUSER: postgres
          PGPASSWORD_ADMIN: postgres
          PGPASSWORD_STANDBY: postgres
        ports:
          - "5432:5432"

      backend:
        build:
          context: ./backend
          dockerfile: Dockerfile.dev
        command: ash -c "rm -f tmp/pids/server.pid && bundle exec rails s -b 0.0.0.0"
        depends_on:
          - db
        ports:
          - "8080:3000"
        environment:
          DATABASE_URL: postgresql://postgres@db/#{app_name}_development
          REDIS_URL: redis://redis:6379/
          RAILS_SERVE_STATIC_FILES: "true"
          RAILS_LOG_TO_STDOUT: "true"
          RAILS_ENV: development
          HOST: 'http://localhost:8080'
        volumes:
          - ./backend:/app

  YAML

  git :init
  git add: '-- .'
  git commit: "-a -m 'Initial commit'"
end
