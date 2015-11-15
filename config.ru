$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "uniuni"
require "rack"

use Rack::CommonLogger
use Rack::ShowExceptions
use Rack::Lint if ENV["RACK_ENV"] == "development"
run Uniuni::App.new(File.expand_path("../config.yml", __FILE__))
