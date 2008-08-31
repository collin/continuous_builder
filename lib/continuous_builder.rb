require 'pp'
require 'colored'

class ContinuousBuilder
  DefaultOptions= {
    :files   => "!no_match",
    :context => Object
  }

  class << self

    def watches id, config
      self.watchers[id] = config
      self.after_editing id, *config[:update] if config[:update]
    end

    def after_editing watch_id, method
      after_editing_callbacks[watch_id] ||= []
      after_editing_callbacks[watch_id] << method
    end

    def after_editing_callbacks
      @after_editing_callbacks ||= {}
    end

    def watchers
      @watchers ||= {}
    end
  end

  def watched_files
    self.class.watchers.inject({}) do |hash, pair|
      watch_id = pair.first
      hash[watch_id] = Dir.glob pair.last[:files]
      hash
    end
  end

  def watched_files_flattened
    watched_files.map{|pair| pair.last}.flatten
  end

  def watched_mtimes
    watched_files_flattened.inject({}) do |hash, filename|
      hash[filename] = File.stat(filename).mtime
      hash
    end
  end

  def cache_watched_mtimes!
    @cached_watched_mtimes = watched_mtimes
  end

  def cached_watched_mtimes
    @cached_watched_mtimes||= {}
  end

  def modified_watched_files
    watched_files.inject({}) do |hash, pair|
      hash[pair.first] = pair.last.select do |file|
        File.stat(file).mtime.to_i > cached_watched_mtimes[file].to_i
      end
      hash
    end 
  end

  def build_continuously loop=true
    cache_watched_mtimes!
    begin
      watch
      sleep 1 if loop
    end while loop
  end

  def watch files=modified_watched_files
    self.class.watchers.each do |watch_id, glob_string|
      act_on_edited_files watch_id, files[watch_id]
    end
  end

  def build_all
    watch watched_files
  end

  def exec_after_editing_callbacks watch_id, path
    callbacks = self.class.after_editing_callbacks[watch_id]
    callbacks.each do |method|
      print_callback_notice method
      self.send method, path
    end unless callbacks.nil? 
  end

  def build_with_module_and_return_path watch_id, path
    config =  self.class.watchers[watch_id]
    if config[:module]
      rendered = render_build path, config 
      build_path = build_path_for(path)
      File.open(build_path, 'w'){|f| f.write(rendered)}
      build_path
    else
      path
    end
  end

  def act_on_edited_files watch_id, paths
    for path in paths
      print_edited_notice watch_id, path
      begin
        update_watched_mtime_cache path
        path = build_with_module_and_return_path watch_id, path
        exec_after_editing_callbacks watch_id, path
      rescue Exception => exception
        print_after_editing_failure_notice exception
      end
    end
  end

  def render_build path, config
    src = File.read(path)
    engine = config[:module]::Engine.new(src)
    engine.render config[:context] 
  end

  def update_watched_mtime_cache path
    cached_watched_mtimes[path] = Time.now
  end

  def print_callback_notice method
    puts "    callback:".orange +" #{method}"
    puts ""
  end

  def print_edited_notice watch_id, path
    puts "edited: #{path.green} #{watch_id.to_s.green}"
    puts ""
  end

  def print_after_editing_failure_notice exception
    puts "callbacks failed because:".red
    puts "    #{exception.inspect}".bold
    puts "    " << exception.backtrace.join("\n    ")
    puts ""
  end

  def ensure_build_path! path
    FileUtils.mkdir_p path
  end
  
  def build_path_for src_path
    dir= File.dirname(src_path)
    bits= File.basename(src_path).split('.')
    name= bits.reject{|bit|bit == bits.last}.join('.')

    dir.gsub!("/#{bits.last}", "")

    ensure_build_path! dir
    "#{dir}/#{name}"
  end
end
