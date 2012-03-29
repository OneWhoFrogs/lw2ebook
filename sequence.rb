require 'rubygems'
require 'open-uri'
require 'nokogiri'
load 'lw2ebook.rb'

class Sequence
  def initialize(posts, format, title, author)
    @posts, @format, @title, @author = posts, format, title, author
  end
  
  def build
    b = Builder.new(@posts, @format, @title, @author)
    b.build
    puts "Whew.  Sequence built."
  end
  
  def self.from_urls(urls, format, title, author)
    posts = urls.map do |url|
      Post.new(url, true)
    end
    Sequence.new(posts, format, title, author)
  end
  
  # I *think* token is the right word, here...
  def self.from_tokens(url, begin_token, end_token)
    
  end
end

if __FILE__ == $0
  unless ARGV.length == 3
    puts "Usage: ruby #{__FILE__} [filetype] [sequence_name] [author]"
    puts "Example: ruby #{__FILE__} epub \"Zombies\" \"Eliezer Yudkowsky\"\n\n"
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
  
  s = Sequence.from_urls(urls, ARGV.first.dup, ARGV[1].dup, ARGV[2].dup)
  s.build    
end