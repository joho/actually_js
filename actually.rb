# https://developer.github.com/v3/search/#search-issues
#
# :shipit:
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
Dotenv.load

class GithubSearch
  def initialize(client)
    @client = client
  end

  def with_rate_limit
    rate_limit = @client.rate_limit
    if rate_limit.remaining == 0
      puts "Rate limited, reset at #{rate_limit.resets_at}"
      while Time.now < rate_limit.resets_at
        print "!"
        sleep 1
      end
    end
    print "."
    yield @client
  end

  def matching_actuallies(issue)
    begin
      issue_comments = with_rate_limit do |c|
        c.get(issue[:comments_url])
      end

      issue_comments.collect do |comment|
        comment[:body] if comment[:body] =~ /actually,/i
      end.compact
    rescue Octokit::UnavailableForLegalReasons,
      []
    end
  end

  def search_issues(page)
    issues = with_rate_limit do |c|
      begin
        yesterday = (Date.today - 1).to_s
        c.search_issues("actually in:comments language:javascript update:>#{yesterday}", page: page)
      rescue Octokit::UnprocessableEntity
        { items: [] }
      end
    end

    # TODO paginate issues
    actuallies = issues[:items].collect do |issue|
      matching_actuallies(issue)
    end.flatten.compact

    puts "\nPAGE #{page}"
    p actuallies

    if issues[:items].count > 0 then
      actuallies += search_issues(client, page + 1)
    end

    actuallies
  end
end

class Generator
  def initialize(dictionary)
    @dictionary= dictionary
  end

  def fresh_actuallies(actuallies)
    actuallies.each do |actually|
      @dictionary.parse_string actually
    end
  end

  def mansplain
    (1...100).collect do |x|
      @dictionary.generate_1_sentence
    end.select do |v|
      v =~ /^actually/i
    end
  end
end

markov = MarkyMarkov::Dictionary.new('dictionary')
generator = Generator.new(markov)

# client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
# github_search = GithubSearch.new(client)
# all_actuallies = github_search.search_issues(1)
#
# generator.fresh_actuallies(all_actuallies)

p generator.mansplain

binding.pry

