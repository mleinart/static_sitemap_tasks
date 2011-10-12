## Generate Sitemap Rake Task ##

This is a small rake task that will crawl a static site locally in the specific directory and generate a sitemap.xml file with a list of links, optionally compressing it.

## Installation ##

  gem install static_sitemap_tasks

## Configuration/Usage ##
To use, require the gem in your Rakefile and install the task with configuration
  require 'static_sitemap_tasks'

  SitemapGenerator::Tasks.install(
    :base_url => 'http://www.mysite.com', # Required
    :change_frequency => 'daily, # Optional, see http://www.sitemaps.org/protocol.php#changefreqdef
    :gzip_output => true, # Optional, default: true
    :index_files => [ 'index.html' ], # Optional, default: [ 'index.html', 'index.htm' ]
    :public_root => 'public' # Optional, default: Dir.pwd
  )

To execute,
  rake generate_sitemap

## More Info ##

http://www.sitemaps.org/protocol.php

## Credits ##

Originally Authored by Chris Marting (http://chriscodes.com/articles/view/54)
Updates by Tom Cocca
Rewrite for static sites by Michael Leinartas
