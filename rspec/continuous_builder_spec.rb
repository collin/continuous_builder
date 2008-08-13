require 'rspec/spec_helper'

FixtureRoot = RootDir + "rspec" + "fixtures"
FixtureRegex = /fixture/

require 'haml'

def modify_file! file="#{FixtureRoot}/src/app/layout.html.haml"
  stamp = File.mtime(file) + 5000
  command = File.utime(stamp, stamp, file)
end

describe modify_file! do
  it "sends a file into the future" do
    file = "#{FixtureRoot}/src/app/layout.html.haml"
    past = File.mtime(file)
    File.stat(file).mtime.should >= past
  end
end

describe ContinuousBuilder do
  it "inherits Class" do
    ContinuousBuilder.class.should == Class
  end

  describe FixtureRoot do
    it "is a fixture" do
      FixtureRoot.to_s.match(FixtureRegex).should_not == nil
    end
  end

  class HamlBuilder < ContinuousBuilder
    builds Haml, 
      :files   => "#{FixtureRoot}/**/*.haml",
      :context => Object
  end

  before(:each) {@builder = HamlBuilder.new}

  describe '.inherited' do
    it "sets Builders constant" do
      Klass = Class.new ContinuousBuilder
      Klass::Builders.should be_empty
    end
  end

  describe '.builds' do
    it "adds to Builders" do
      FauxBuilder = Class.new ContinuousBuilder
      FauxBuilder.builds Haml
      FauxBuilder::Builders.should_not be_empty
    end
  end

  describe "#build" do
    before(:each) do
      @builder.cache_mtimes!
    end
  end

  describe "#build_all" do
    it "builds all unmodified files" do
      src= Dir.glob "#{FixtureRoot}/src/app/*.html.haml"
      build_glob= "#{FixtureRoot}/build/app/*.html"
      build= Dir.glob build_glob
      FileUtils.rm build, :force => true
      @builder.build_all
      Dir.glob(build_glob).length.should == src.length
    end
  end

  describe "#build_files" do
    before(:each) do
      @builder.cache_mtimes!
    end

    it "renders html documents" do
      src= Dir.glob "#{FixtureRoot}/src/app/*.html.haml"
      build_glob= "#{FixtureRoot}/build/app/*.html"
      build= Dir.glob build_glob
      FileUtils.rm build, :force => true

      @builder.build_files(@builder.files[:Haml], :Haml, {:context => Object})
      Dir.glob(build_glob).length.should == src.length
    end
  end

  describe "#build_path_for" do  
    it "constructs a build path" do
      @builder.build_path_for("#{FixtureRoot}/src/some_file.extension.processor").should == "#{FixtureRoot}/build/some_file.extension"
    end
    
    it "maintains path depth" do
      @builder.build_path_for("#{FixtureRoot}/src/place/some_file.extension.processor").should == "#{FixtureRoot}/build/place/some_file.extension"
    end

=begin
Not using this, removed it when builder became Class    
    it "builds multi dot files" do
      @builder.build_path_for("spec.html", "#{FixtureRoot}/src/place/some_file.extension.processor").should == "#{FixtureRoot}/build/place/some_file.spec.html"
    end
=end
  end

  describe "#files" do
    it "contains haml files" do
      @builder.files[:Haml].should_not be_empty
    end    
  end
  
  describe "#files_flattened" do
    it "returns an array" do
      @builder.files_flattened.class.should == Array
    end
    
    it "is flat" do
      files = @builder.files_flattened
      files.should == files.flatten
    end
  end

  describe "#mtimes" do
    it "returns a hash" do
      @builder.mtimes.class.should == Hash
    end
  
    it "keys are filenames" do
      @builder.mtimes.reject{|key, value| File.exists? key}.should be_empty
    end
  
    it "values are Times" do
      @builder.mtimes.reject{|key, value| value.is_a? Time}.should be_empty
    end
  end
  
  describe "#modified_files" do
    before(:each) do
      @builder.cache_mtimes!
    end
  
    it "returns a Hash" do
      @builder.modified_files.class.should == Hash
    end
  
    it "contains modified files names" do
      modify_file!
      @builder.modified_files[:Haml].should_not be_empty
    end
  
    it "ignores unmodified files" do
      @builder.modified_files[:Haml].should be_empty
    end
  
    it "contains new files" do
      file = "#{FixtureRoot}/src/app/touched.html.haml"
      FileUtils.touch(file)
      @builder.modified_files[:Haml].should include(file)
      FileUtils.rm(file)
    end
  end
  
  describe "#cache_mtimes!" do
    it "caches_mtimes" do
      @builder.cache_mtimes!
      @builder.instance_variable_get(:@cached_mtimes).should == @builder.mtimes
    end
  end
  
  describe "#cached_mtimes" do
    before(:each) do
      @builder.cache_mtimes!
    end
  
    it "returns a hash" do 
      @builder.cached_mtimes.class.should == Hash
    end
  
    it "same as mtimes if no change" do
      @builder.cached_mtimes.should == @builder.mtimes
    end
  
    it "holds old mtimes" do
      modify_file!
      @builder.cached_mtimes.should_not == @builder.mtimes
    end
  end
  
  describe "#ensure_build_path!" do
    it "makes all parent dirs" do
      FileUtils.rm_rf "#{FixtureRoot}/build"
      @builder.ensure_build_path! "#{FixtureRoot}/build/app/layout.html.haml"
      File.exists?("#{FixtureRoot}/build/app/").should == true
      FileUtils.rm_rf "#{FixtureRoot}/build/app"
    end
  end
  
  describe "#build_continuously" do
    it "caches mtimes" do
      @builder.build_continuously false
      @builder.instance_variable_get(:@cached_mtimes).should_not be_nil
    end
  
    it "builds" do 
      @builder.should_receive(:build).once
      @builder.build_continuously false
    end
  end
end

describe ContinuousBuilder::SrcRegex do
  it "matches 'src'" do
    ContinuousBuilder::SrcRegex.match("string-with-src-in-it").should_not == nil
  end
end

describe ContinuousBuilder::BuildDirectory do
  it "is 'build'" do
    ContinuousBuilder::BuildDirectory.should == 'build'
  end
end
