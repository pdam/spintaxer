require 'rubygems'
require 'fileutils'
require 'hpricot'
require 'open-uri'
require 'progressbar'

attributes = ['href', 'src']
file_extensions = ['jpg', 'jpeg', 'gif', 'png', 'tiff']

def fetch_extension(url)      
  return url.split('.').last
end

def fetch_file(uri)
  progress_bar = nil 
  open(uri, :proxy => nil,
    :content_length_proc => lambda { |length|
      if length && 0 < length
        progress_bar = ProgressBar.new(uri.to_s, length)
      end 
    },
    :progress_proc => lambda { |progress|
      progress_bar.set(progress) if progress_bar
    }) {|file| return file.read}        
end

def save_file(file_uri)  
  open(file_uri.to_s.gsub!(/[\/:]/, '_'), 'wb') { |file| 
    file.write(fetch_file(file_uri)); puts
  }
end

def scrape_urls(html, attributes)      
  Hpricot.buffer_size = 262144
  attributes.each { |attribute|
    Hpricot(html).search("[@#{attribute}]").map { |tag|
      yield tag["#{attribute}"]
    }
  }
end

def to_absolute_uri(original_uri, url)
  url = URI.parse(url.downcase)     
  url = original_uri + url if url.relative?  
  return url.normalize        
end

puts 'Enter a URL:'
original_uri = URI.parse(gets.chomp!)

html = nil

begin
  open(original_uri, :proxy => nil) {|source| html = source.read()}

  scrape_urls(html, attributes) { |url|
    if file_extensions.include?(fetch_extension(url)) then
      save_file(to_absolute_uri(original_uri, url))
    end
  }
rescue => e
  puts e
end