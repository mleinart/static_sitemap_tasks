require 'rubygems'
require 'builder'
require 'hpricot'
require 'time'
require 'cgi'
require 'uri'


module SitemapGenerator
  class Tasks
    include Rake::DSL

    def self.install(options = {})
      dir = options.delete(:dir) || Dir.pwd
      self.new(options).install
    end

    def initialize(options = {})
      # Canonical domain of published site
      @base_url = options[:base_url]
      # Change frequency - see: http://www.sitemaps.org/protocol.php#changefreqdef
      @change_frequency = options[:change_frequency]
      # Date mode - one of [ 'git', 'mtime' ]
      @date_mode = options[:date_mode]
      # Compress output to sitemap.xml.gz
      @gzip_output = options[:gzip_output] || true
      # Index pages
      @index_files = options[:index_files] || [ 'index.html', 'index.htm' ]
      # Root of files to crawl
      @public_root = options[:public_root] || Dir.pwd
    end

    def install
      namespace :sitemap do
        desc "Generate a sitemap based on the contents of #{@public_root}"
        task :generate do
          generate_sitemap
        end

        desc "Ping providers to notify them that a new sitemap.xml is available"
        task :ping do
          ping_search_engines
        end
      end
    end

    # uses Hpricot to grab links from a URI
    # adds uri to @pages_crawled
    # loops each link found
    # adds link to pages array if it should be included, unless it already exists
    def crawl_for_links(link)
      if link.include?('http')
        return unless link_path.include?(@base_url)
        link_path = link.sub!(@base_url,'')
      else
        link_path = link
      end
      file_path = resolve_file_path(File.join(@public_root, link_path))

      if file_path.nil?
        puts "Warning: Unable to resolve #{link_path} to a local file"
        return
      end

      puts "Inspecting #{file_path}...\n"
      doc = Hpricot(open(file_path)) rescue nil
      return unless doc
      @pages_crawled << link
      last_updated = find_date(file_path)
      @page_times[link] = last_updated if last_updated

      (doc/"a").each do |a|
        if a['href'] && should_be_included?(a['href'])
          @pages << a['href'] unless(link_exists?(a['href'],@pages))
        end
      end
    end

    def find_date(file)
      case @date_mode
      when 'git'
        raw_date = %x[git log -n 1 --date=iso --format="%ad" #{file}]
        raw_date.strip!()
        # we need ISO with no spaces
        Time.parse(raw_date).iso8601 rescue nil
      when 'mtime'
        mtime = File.mtime(file) rescue nil
        mtime.iso8601 if mtime
      end
    end

    def generate_sitemap
      # holds pages to go into map, and pages crawled
      @pages = []
      @pages_crawled = []
      @page_times = {}

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
      xml.urlset("xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                 "xsi:schemaLocation" => "http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd",
                 "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9") {
        # loop through array of pages, and build sitemap.xml
        @pages.sort.each {|link|
          xml.url {
            xml.loc URI.join(@base_url, link).to_s
            # TODO - set changefreq dynamically per page
            xml.changefreq @change_frequency unless @change_frequency.nil?
            xml.lastmod @page_times[link] unless @page_times[link].nil?
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

    def ping_search_engines
      require 'open-uri'
      if @gzip_output
        url = URI.join(@base_url,'sitemap.xml.gz').to_s
      else
        url = URI.join(@base_url,'sitemap.xml').to_s
      end
      index_location = CGI.escape(url)

      # engines list from http://en.wikipedia.org/wiki/Sitemap_index
      {:google => "http://www.google.com/webmasters/sitemaps/ping?sitemap=#{index_location}",
        :ask => "http://submissions.ask.com/ping?sitemap=#{index_location}",
        :bing => "http://www.bing.com/webmaster/ping.aspx?siteMap=#{index_location}",
        :sitemap_writer => "http://www.sitemapwriter.com/notify.php?crawler=all&url=#{index_location}"}.each do |engine, link|
        begin
          open(link)
          puts "Successful ping of #{engine.to_s}" if verbose
        rescue Timeout::Error, StandardError => e
          puts "Ping failed for #{engine.to_s}: #{e.inspect}" if verbose
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
