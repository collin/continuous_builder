require 'rubygems'
require 'pathname'
require 'spec'

__DIR__ = path = Pathname.new(__FILE__).dirname.expand_path


task :default => "spec:all"

namespace :spec do
  task :default => :all

  task :prepare do 
    @specs= Dir.glob(__DIR__ +"rspec"+"**"+"*.rb").join(' ')
    p @specs
  end
  
  task :all => :prepare do
    system "spec #{@specs}"
  end
  
  task :doc => :prepare do
    system "spec #{@specs} --format specdoc"
  end
end

task :cleanup do 
  Dir.glob("**/*.*~")+Dir.glob("**/*~").each{|swap|FileUtils.rm(swap, :force => true)}
end

namespace :gem do
  task :version do
    @version = "0.0.1"
  end

  task :build => :spec do
    load __DIR__ + "continuous_builder.gemspec"
    Gem::Builder.new(@continuous_builder_gemspec).build
  end

  task :install => :build do
    cmd = "gem install continuous_builder -l"
    system cmd unless system "sudo #{cmd}"
    FileUtils.rm(__DIR__ + "continuous_builder-#{@version}.gem")
  end

  task :spec => :version do
    file = File.new(__DIR__ + "continuous_builder.gemspec", 'w+')
    FileUtils.chmod 0755, __DIR__ + "continuous_builder.gemspec"
    spec = %{
Gem::Specification.new do |s|
  s.name             = "continuous_builder"
  s.date             = "2008-07-21"
  s.version          = "#{@version}"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.has_rdoc         = false
  s.summary          = "A little class to watch the filesystem and then provide callbacks when files are saved."
  s.authors          = ["Collin Miller"]
  s.email            = "collintmiller@gmail.com"
  s.homepage         = "http://github.com/collin/jass"
  s.files            = %w{#{(%w(README Rakefile.rb) + Dir.glob("{lib,rspec}/**/*")).join(' ')}}
  
  s.add_dependency  "rake"
  s.add_dependency  "rspec"
end
}

  @continuous_builder_gemspec = eval(spec)
  file.write(spec)
  end
end