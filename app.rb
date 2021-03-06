require 'rubygems'
require 'bundler'
require 'sequel'
Bundler.require

# Database setup
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://tfa.db')
DB.create_table? :tweets do
  primary_key :id
  String :content
  BigNum :twitter_id, :type => :bigint
end
tweets = DB[:tweets]

# reset stylesheet
get '/stylesheets/reset.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  css :reset
end

# main stylesheet
get '/stylesheets/main.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  css :main
end

# homepage
get '/' do
  # so hacky
  if @env['SERVER_NAME'] == 'tonyfuckingabbott.heroku.com'
    redirect 'http://tonyfuckingabbott.com', 301
  end
  # get the max id from the database to pass to our search query
  since_id = tweets.max(:twitter_id)
  page = 1
  page_max = 20
  curses = %w{shit fuck cunt arse arsehole prick bastard fucking}

  # load all the new tweets into the DB
  while true do
    item_count = 0
    # 20 per page - twitter docs say 100, but seems to be less, so we
    # cover our bases for pagination. this pagination method also leaves
    # a small possibility of duplicates, but it's not a big deal.
    options = {count: page_max, result_type: 'recent', since_id: since_id}

    twitter.search(%Q{"tony abbott" #{curses.join(" OR ")} -rt}, options).take(20).each do |item|
      tweets.insert(:twitter_id => item.id, :content => item.text)
      item_count = item_count + 1
    end
    # if we don't have more than 20 items, we can exit
    break if item_count < page_max
    page = page + 1
  end

  @results = []

  @all_results = tweets.order(:twitter_id).reverse.each do |item|
    # ignore items in the blacklist file or that start with rt/RT (retweets)
    unless BLACKLISTED_STRINGS.any? {|i| item[:content].downcase.match(i.downcase)} || item[:content].downcase.match(/^rt/)
      @results << '<p id="' + item[:id].to_s + '">' +
        item[:content].gsub(/^@\w[a-z]+\s/, '').
        gsub(/((ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/i, '<a href="\1">\1</a>').
        gsub(/(@\w[a-z]+)(\s|\S)/i, '<a href="http://twitter.com/\1">\1</a>').
        gsub(/(Tony Abbott\W?)/i, '<strong>\1</strong>').
        gsub(/(fuck\W|fucking\W|fucked\W|shit\W|arse\W|arsehole\W|prick\W|bastard\W|cunt\W)/i, '<em>\1</em>') +
        '</p><a class="permalink" href="#' + item[:id].to_s + '">permalink</a>'
    else
      puts "This was blacklisted: #{item[:content]}"
    end
  end

  # Make heroku cache this page
  response.headers['Cache-Control'] = 'public, max-age=300'

  haml :index, :options => {:format => :html4, :attr_wrapper => '"'}
end

# Configure Block.
configure do
  BLACKLISTED_STRINGS = []
  # read blacklist file.
  File.open(File.join(File.dirname(__FILE__), '/blacklist.txt'), 'r') do |file|
    while line = file.gets
        BLACKLISTED_STRINGS << line.strip
    end
  end
end

def twitter
  @twitter ||= Twitter::REST::Client.new do |config|
    config.consumer_key         = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret      = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token         = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret  = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  @twitter
end
