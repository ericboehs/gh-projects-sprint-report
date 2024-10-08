# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'development'

$LOAD_PATH.unshift 'lib'
require 'logger'
$logger ||= Logger.new $stdout # rubocop:disable Style/GlobalVars

require 'bundler/setup'
Bundler.require 'default', ENV['RACK_ENV']

require 'csv'
require 'dotenv'
require 'github/project'

require 'action_view'
require 'action_view/helpers'
require 'active_record'
require_relative './models/concerns/removable'
require_relative './models/issue'
require_relative './models/issues_sprint'
require_relative './models/sprint'
require_relative './models/project'

database_url = ENV['RACK_ENV'] == "test" ? ENV['TEST_DATABASE_URL'] : ENV['DATABASE_URL']
ActiveRecord::Base.establish_connection(database_url)
