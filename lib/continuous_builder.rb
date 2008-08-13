class ContinuousBuilder
  SrcRegex=  /src/
  BuildDirectory= "build"
  DefaultOptions= {
    :files   => "!no_match",
    :context => Object
  }

  class << self
    def inherited klass
      klass.const_set :Builders, {}
    end

    def builds builder_module=Module, options={}
      options = DefaultOptions.merge(options)
      self::Builders[builder_module.name.to_sym] = options
    end
  end

  def files
    self.class::Builders.inject({}) do |hash, builder|
      module_name = builder.first
      hash[module_name] = Dir.glob builder.last[:files]
      hash
    end
  end
  
  def files_flattened
    files.map{|pair| pair.last}.flatten
  end

  def mtimes
    files_flattened.inject({}) do |hash, filename|
      hash[filename] = File.stat(filename).mtime
      hash
    end
  end

  def cache_mtimes!
    @cached_mtimes = mtimes
  end

  def cached_mtimes
    @cached_mtimes
  end

  def modified_files
    files.inject({}) do |hash, pair|
      hash[pair.first] = pair.last.select do |file|
        File.stat(file).mtime.to_i > cached_mtimes[file].to_i
      end
      hash
    end 
  end

  def build_continuously loop=true
    cache_mtimes!
    begin
      build
      sleep 1 if loop
    end while loop
  end
  
  def build files=modified_files
    self.class::Builders.each do |module_name, options|
      build_files files[module_name], module_name, options
    end
  end

  def build_all
    build files
  end    

  def build_files paths, module_name, options
    builder = Object.const_get(module_name)
    for path in paths
      file = File.new build_path_for(path), 'w'

      p "building: #{path}"
      p "as:       #{file.path}"
      p ""
      
      begin
        src = File.read(path)
        engine = builder::Engine.new(src)

        cached_mtimes[path] = Time.now

        rendered = engine.render options[:context]
        file.write(rendered)
        file.close
      rescue Exception => e
        p "failed to build because:"
        p e.inspect
        p ""
      end
    end
  end
  
  def ensure_build_path! path
    FileUtils.mkdir_p path
  end
  
  def build_path_for src_path
    dir= File.dirname(src_path).gsub(self.class::SrcRegex, self.class::BuildDirectory)
    bits= File.basename(src_path).split('.')
    name= bits.reject{|bit|bit == bits.last}.join('.')

    ensure_build_path! dir
    "#{dir}/#{name}"
  end
end