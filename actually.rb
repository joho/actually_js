# https://developer.github.com/v3/search/#search-issues
#
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
Dotenv.load

def with_rate_limit(client)
  rate_limit = client.rate_limit
  if rate_limit.remaining == 0
    puts "Rate limited, reset at #{rate_limit.resets_at}"
    while Time.now < rate_limit.resets_at
      print "!"
      sleep 1
    end
  end
  print "."
  yield client
end

def matching_actuallies(client, issue)
  begin
    issue_comments = with_rate_limit(client) do |c|
      c.get(issue[:comments_url])
    end

    issue_comments.collect do |comment|
      comment[:body] if comment[:body] =~ /actually,/i
    end.compact
  rescue Octokit::UnavailableForLegalReasons
    []
  end
end

def search_issues(client, page)
  issues = with_rate_limit(client) do |c|
    c.search_issues("actually in:comments language:javascript", page: page)
  end

  # TODO paginate issues
  actuallies = issues[:items].collect do |issue|
    matching_actuallies(client, issue)
  end.flatten.compact

  puts "\nPAGE #{page}"
  p actuallies

  if issues[:items].count > 0 then
    actuallies += search_issues(client, page + 1)
  end

  actuallies
end

client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])

search_issues(client, 1)

binding.pry

