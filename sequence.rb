require 'open-uri'
require 'nokogiri'
load 'lw2ebook.rb'

class Sequence
  def initialize(posts, format, title)
    @posts, @format, @title = posts, format, title
  end
  
  def build
    b = Builder.new(@posts, @format, @title)
    b.build
    puts "Whew.  Sequence built."
  end
  
  def self.from_urls(urls, format, title)
    posts = urls.map do |url|
      Post.new(url, true)
    end
    Sequence.new(posts, format, title)
  end
  
  # I *think* token is the right word, here...
  def self.from_tokens(url, begin_token, end_token)
    
  end
end

if __FILE__ == $0
  unless ARGV.length == 2
    puts "Usage: ruby #{__FILE__} [filetype] [sequence_name]"
    puts "Example: ruby #{__FILE__} epub \"Zombies\"\n\n"
    exit
  end
  
  f = File.read('urls.txt')
  n = Nokogiri::HTML(f)
  urls = n.xpath('//a[@href]').inject([]) do |links, link|
    url = link.attributes['href'].value
    if url =~ Abs_regex || url =~ Rel_regex
      links << url
    end
    links
  end
  
  s = Sequence.from_urls(urls, ARGV.first.dup, ARGV[1].dup)
  s.build    
end