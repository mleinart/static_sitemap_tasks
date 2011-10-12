require 'rubygems'
require 'builder'
require 'hpricot'
require 'uri'


module SitemapGenerator
  class Tasks
    include Rake::DSL

    def self.install(options = {})
      dir = options.delete(:dir) || Dir.pwd
      self.new(options).install
    end

    def initialize(options = {})
      # Root of files to crawl
      @public_root = options[:public_root] || Dir.pwd
      # Change frequency - see: http://www.sitemaps.org/protocol.php#changefreqdef
      @change_frequency = options[:change_frequency]
      # Canonical domain of published site
      @base_url = options[:base_url]
      # Index pages
      @index_files = options[:index_files] || [ 'index.html', 'index.htm' ]
      # Compress output to sitemap.xml.gz
      @gzip_output = options[:gzip_output] || true
    end

    def install
      desc "Generate a sitemap based on the contents of #{@public_root}"
      task 'generate_sitemap' do
        generate_sitemap
      end
    end

    def generate_sitemap
      # holds pages to go into map, and pages crawled
      @pages = []
      @pages_crawled = []

      # start with index pages
      crawl_for_links('/')

      # crawl each page in pages array unless it's already been crawled
      @pages.each {|page|
        crawl_for_links(page) unless @pages_crawled.include?(page)
      }

      # create xml for sitemap
      xml = Builder::XmlMarkup.new( :indent => 2 )
      xml.instruct!
      xml.comment! "Generated on: " + Time.now.to_s
      xml.urlset("xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9") {
        # loop through array of pages, and build sitemap.xml
        @pages.sort.each {|link|
          xml.url {
            xml.loc URI.join(@base_url, link)
            # TODO - set changefreq dynamically per page
            xml.changefreq @change_frequency unless @change_frequency.nil?
          }
        }
      }

      # convert builder xml to xml string, and save
      xml_string = xml.to_s.gsub("<to_s/>","")
      filename = File.join(@public_root,'sitemap.xml')

      if @gzip_output
        require 'zlib'
        filename << '.gz'
        xml_file = Zlib::GzipWriter.open(filename)
      else
        xml_file = File.open(filename, 'w')
      end

      xml_file << xml_string
      xml_file.close
    end

    # uses Hpricot to grab links from a URI
    # adds uri to @pages_crawled
    # loops each link found
    # adds link to pages array if it should be included, unless it already exists
    def crawl_for_links(link_path)
      if link_path.include?('http')
        return unless link_path.include?(@base_url)
        link_path.sub!(@base_url,'')
      end
      file_path = resolve_file_path(File.join(@public_root, link_path))

      if file_path.nil?
        puts "Warning: Unable to resolve #{link_path} to a local file"
        return
      end

      puts "Inspecting #{file_path}...\n"
      doc = Hpricot(open(file_path)) rescue nil
      return unless doc
      @pages_crawled << link_path
      (doc/"a").each do |a|
        if a['href'] && should_be_included?(a['href'])
          @pages << a['href'] unless(link_exists?(a['href'],@pages))
        end
      end
    end

    def resolve_file_path(path)
      file_path = nil

      if File.directory?(path)
        @index_files.each do |f|
          index_file = File.join(path,f)
          if File.exists?(index_file)
            file_path = index_file
            break
          end
        end
      else
        if File.exists?(path)
          file_path = path
        end
      end

      file_path
    end

    # returns true if any of the following are true:
    # - link isn't external (eg, contains 'http://') and doesn't contain 'mailto:'
    # - is equal to '/'
    # - link contains @base_url
    def should_be_included?(str)
      if ((!str.include?('http://') && !str.include?('mailto:')) || str == '/' || str.include?(@base_url))
        unless str.slice(0,1) == "#"
          return true
        end
      end
    end

    # checks each value in a given array for the given string
    # removes '/' character before comparison
    def link_exists?(str, array)
      array.detect{|l| strip_slashes(l) == strip_slashes(str)}
    end

    # removes '/' character from string
    def strip_slashes(str)
      str.gsub('/','')
    end
  end
end
