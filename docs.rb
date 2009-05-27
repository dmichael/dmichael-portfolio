require 'rubygems'
require 'sinatra'
require 'rdiscount'
require 'grit'

include Grit



root_dir = File.dirname(__FILE__)

set :environment, :production
set :root,    root_dir
set :app_file,  File.join(root_dir, 'service.rb')
disable :run

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

set :app_file, __FILE__

get '/README' do
  render_topic './README'
end

get '/' do
  #cache_long
  render_topic 'index'
end

get '/:topic' do
  #cache_long
  render_topic params[:topic]
end

get '/css/docs.css' do
  #cache_long
  content_type 'text/css'
  erb :css, :layout => false
end

before do
  @asset_host = ENV['ASSET_HOST']
end

helpers do
  def render_topic(topic)
    if ENV['RACK_ENV'] = "development"
      last_commit
      @last_commit = File.open("log/commit.log").readlines
    end
    source = File.read(topic_file(topic))
    @content = markdown(source)
    @title, @content = title(@content)
    @toc, @content = toc(@content)
    @topic = topic
    erb :topic
  end

  def last_commit
    $repo = Repo.new(".")

    FileUtils.mkdir_p 'log' unless File.exists?('log')
    #log = File.new("log/commit.log", "a")

    doc = $repo.commits.last.date
    File.open("log/commit.log", 'w') {|f| f.write(doc) }
  end

  def sections
    [
      [ 'web-apps', 'Web Apps' ],
      [ 'sound', 'Sound' ],
      [ 'publications', 'Publications' ],


      [ 'talks', 'Invited Talks' ],
      [ 'education', 'Education' ],
      [ 'network', 'Network' ],
    ]
  end
  
  def cache_long
    response['Cache-Control'] = "public, max-age=#{60 * 60}" unless development?
  end

  def notes(source)
    source.gsub(/NOTE: (.*)/, '<table class="note"><td class="icon"></td><td class="content">\\1</td></table>')
  end

  def markdown(source)
    RDiscount.new(notes(source), :smart).to_html
  end

  def topic_file(topic)
    if topic.include?('/')
      topic
    else
      "#{options.root}/docs/#{topic}.txt"
    end
  end

  def title(content)
    title = content.match(/<h1>(.*)<\/h1>/)[1]
    content_minus_title = content.gsub(/<h1>.*<\/h1>/, '')
    return title, content_minus_title
  end

  def slugify(title)
    title.downcase.gsub(/[^a-z0-9 -]/, '').gsub(/ /, '-')
  end

  def toc(content)
    toc = content.scan(/<h2>([^<]+)<\/h2>/m).to_a.map { |m| m.first }
    content_with_anchors = content.gsub(/(<h2>[^<]+<\/h2>)/m) do |m|
      "<a name=\"#{slugify(m.gsub(/<[^>]+>/, ''))}\"></a>#{m}"
    end
    return toc, content_with_anchors
  end

  def next_section(current_slug)
    return sections.first if current_slug.nil?

    sections.each_with_index do |(slug, title), i|
      if current_slug == slug and i < sections.length-1
        return sections[i+1]
      end
    end
    nil
  end

  alias_method :h, :escape_html
end
