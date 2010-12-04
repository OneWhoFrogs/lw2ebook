#!/usr/bin/env ruby -KU
# encoding: UTF-8

# Author: OneWhoFrogs <onewhofrogs@gmail.com>
# Feel free to contact me for any problem or idea -- I love email!

require 'nokogiri'
require 'open-uri'
require 'tmpdir'
require 'fileutils'
require 'pp'
require 'digest/sha2'

# Should be changed depending on your system. If not using a Unix-based OS, also change the "rm rf" command below.
Path_to_ebook_convert = '/Applications/calibre.app/Contents/MacOS/ebook-convert'
Abs_regex             = /^http:\/\/lesswrong.com\/lw\/[a-zA-Z0-9]{2,3}\/[a-zA-Z0-9_]*\/?$/
Rel_regex             = /^\/lw\/[a-zA-Z0-9]{2,3}\/[a-zA-Z0-9_]*\/?$/
Img_regex             = /(?i)\.(jpg|png|gif)$/
Identifier_space      = '​'
Silenced              = false

class Post
  attr_reader :top_level
  @@cached_posts = Hash.new
  Base_url = 'http://lesswrong.com'
  
  def initialize(_url, top_level = false)
    @_url = case _url
      when Rel_regex then Base_url + _url
      when Abs_regex then _url
      else raise "Invalid URL: must lead to a LessWrong post. URL: \"#{_url}\""
    end
    @top_level = top_level
    if top_level
      puts "Loading main post...\t#{url.split('/').last}" unless Silenced
    end
    @page = Nokogiri::HTML(open(url))
    @@cached_posts[url] = self
    self
  end
  
  def title
    @_title ||= @page.xpath('//title').text.sub(" - Less Wrong", "")
  end
  
  def author
    # cleaner? eh, I suppose it could be.
    @_author ||= @page.xpath('//span[@class="author"]').first.children.first.text
  end
  
  def content
    @_content ||= @page.xpath('//div[@class="md"]')[1].inner_html.strip
  end
  
  def content=(text)
    @_content = text
  end
  
  def url
    @_url
  end
  
  def slug
    @_slug ||= url.split('/').last
  end
  
  def interlinks
    def load_interlinks
      links = Nokogiri::HTML(content).xpath('//a[@href]').select do |link|
        (link.attributes['href'].value =~ Abs_regex) || (link.attributes['href'].value =~ Rel_regex)
      end
      loaded_links = links.map do |link|
        post_url = link.attributes['href'].value
        full_url = Base_url + post_url
        already_loaded = @@cached_posts.include?(full_url)
        if already_loaded
          post = @@cached_posts[full_url]
        else
          puts "Loading interlink...\t#{post_url.split('/').last}" unless Silenced
          post = Post.new(post_url)
        end
        post
      end
      loaded_links or Array.new
    end
    # TODO: is it faster to make a new Nokogiri object from content or search all of the already created @page object?
    @_interlinks ||= load_interlinks
  end
end

class Builder
  Temp_folder = "lw_temp" + Random.rand(10000).to_s
  def initialize(posts, format, title, slug=nil)
    @posts = case posts
      when Post then [posts]
      when Array then posts
      else raise "Please give an array of Posts or a single Post."
    end
    @title = title
    @slug = case slug.nil?
      when true then
      s = title.gsub(/[^a-zA-Z0-9]+/, "_").downcase
      s.gsub(/^_+/, "").gsub(/_+$/, "") # remove underscores on either side
      when false then
        slug
    end
    @format = format.delete('.')
  end
  
  def write_html
    Dir::mkdir(Temp_folder) unless File.directory?(Temp_folder)
    write_toc
    @posts.each do |post|
      write_post(internalize_links(post))

      post.interlinks.each do |interlink|
        write_post(interlink)
      end
    end
    
    copy_logo
  end
  
  def convert
    puts "Compiling into an ebook..." unless Silenced
    `#{Path_to_ebook_convert} #{Temp_folder}/toc.html #{@slug}.#{@format} --title "#{@title}" --authors "LessWrong" --level1-toc "//top_level" --level2-toc "interlink" --toc-filter "^((?!#{Identifier_space}).)*$" --cover "logo.png" --comments "Less Wrong is a community devoted to refining the art of human rationality."`
    `rm -rf #{Temp_folder}`
  end
  
  def build
    write_html
    convert
  end
  
  private
  def write_post(post)
    content = download_images(post.content)
    urls_hash = Hash.new
    @posts.each do |post|
      urls_hash[post.url] = true
    end
    if urls_hash.include?(post.url)
      title = post.title
    else
      title = "(Related) #{post.title}"
    end
    File.open(temp_path(post.slug), 'w') do |f|
      f.write("<html xmlns=\"http://www.w3.org/1999/xhtml\"><head></head><body>" +
              "<h2 class=\"title\">#{title}</h2>Written by #{post.author}<br /><p>#{content}</p></body></html>")
    end
  end
  
  def write_toc
    notice = "<h3>Quick Note About Formatting</h3>On Less Wrong, users will often link to related posts.  These are included within this ebook, so that a link which leads to another post will display the post's title in parentheses.  All links that don't have a post title in parentheses link to a web page, and not another section of this ebook.<br/>"
    toc = "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>#{@title}</title></head><body class=\"vcenter\">" +
          "<div class=\"container\"><table><tr><td><h2 class=\"title\">#{@title}</h2>" +
          "</td></tr></table>#{notice}</div><ul>"
          
    @posts.each.with_index(1) do |post, i|
      toc += "<li><top_level><a href=\"#{post.slug}.html\">#{i.to_s + '. ' + post.title + Identifier_space}</a></top_level></li>"
      #post.interlinks.each.with_index(1) do |link, j|
      #  toc += "<li><interlink><a href=\"#{link.slug}.html\">#{i.to_s + '.' + j.to_s + ' ' + link.title + Identifier_space}</a></interlink></li>"
      #end
    end
    
    toc += "</ul></body></html>"
    
    File.open(temp_path('toc'), 'w') do |f|
      f.write(toc)
    end
  end
  
  def internalize_links(post)
    page = Nokogiri::HTML(post.content)
    
    slugs_hash = Hash.new
    post.interlinks.each do |link|
      slugs_hash[link.slug] = link
    end
    page.xpath('//a[@href]').each do |link|
      href = link.attributes['href'].value
      if href =~ Rel_regex || href =~ Abs_regex 
        slug = href.split('/').last
        link.attributes['href'].value = slug + '.html'
        link.inner_html += " <i>(#{slugs_hash[slug].title})</i>"
      end
    end
    
    post.content = page.to_html
    post
  end
  
  def download_images(content)
    page = Nokogiri::HTML(content)
    page.xpath('//img[@src]').each do |img|
      url = img.attributes['src'].value
      # skip invalid images
      unless url =~ Img_regex
        next
      end
      if url =~ /^\/static\//
        url = "http://lesswrong.com" + url
      end
      
      extension = url.split('.').last
      name = Digest::MD5.hexdigest(url)[0..5] + '.' + extension
      path = "#{Temp_folder}/#{name}"
      
      unless File.exists?(path)
        open(path, 'wb') do |f|
          puts "\t(Downloading #{url})" unless Silenced
          f.write(open(url).read)
        end
      end
      
      img.attributes['src'].value = name
    end
    
    page.to_html
  end
  
  def copy_logo
    if File.exists?('logo.png')
      FileUtils.cp('logo.png', Temp_folder + '/logo.png')
    end
  end
  
  def temp_path(filename)
    Temp_folder + '/' + filename + '.html'
  end
end

###
# Command Line
###
if __FILE__ == $0
  unless ARGV.length == 2
    puts "Usage: ruby #{__FILE__} [filetype] [url]"
    puts "Example: ruby #{__FILE__} epub http://lesswrong.com/lw/34a/goals_for_which_less_wrong_does_and_doesnt_help/\n\n"
    exit
  end
  
  p = Post.new(ARGV[1].dup, true)
  eb = Builder.new(p, ARGV.first.dup, p.title, p.slug)
  eb.build
end