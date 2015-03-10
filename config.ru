require 'dalli'
require 'rack/cache'
require 'sinatra'

if memcachier_servers = ENV["MEMCACHIER_SERVERS"]
  cache = Dalli::Client.new memcachier_servers.split(','), {
    username: ENV['MEMCACHIER_USERNAME'],
    password: ENV['MEMCACHIER_PASSWORD'],
  }
  use Rack::Cache, verbose: true, metastore: cache, entitystore: cache
end

require File.expand_path('../app', __FILE__)

run Sinatra::Application
