# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "static_sitemap_tasks"
  s.version     = "0.1"
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Rake tasks to manage sitemap.xml generation for static sites'
  s.description = 'Rake tasks to manage sitemap.xml generation for static sites'

  s.required_ruby_version     = ">= 1.8.7"
  s.required_rubygems_version = ">= 1.3.6"

  s.authors     = ["Michael Leinartas", "Tim Cocca", "Chris Martin"]
  s.email       = ["mleinartas@gmail.com"]
  s.homepage    = "https://github.com/mleinart/static_sitemap_tasks"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path  = 'lib'

  s.add_development_dependency "rake", ">= 0.8.7"
  s.add_development_dependency "bundler", ">= 1.0"
end
