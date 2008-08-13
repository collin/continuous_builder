require 'rubygems'
require 'pathname'
RootDir  = Pathname.new(__FILE__).dirname.expand_path + ".."
require 'lib/continuous_builder'