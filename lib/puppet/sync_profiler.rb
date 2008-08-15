class SyncProfiler

  DEFAULTS = {:retained => false, :deltas => true, :logdir => "/tmp/memory_log", :logfile => "profile.log"}
 
  attr_accessor :opt, :delta, :curr, :prev, :watched, :retained, :file, :sync

  def initialize(opts={})
    @opt = DEFAULTS.dup.merge(opts)

    @curr ||= Hash.new { |hash, key| hash[key] = [] }
    @prev ||= Hash.new { |hash, key| hash[key] = [] }
    @watched ||= Hash.new { |hash, key| hash[key] = [] }

    Dir.mkdir(opt[:logdir]) unless File.directory?(opt[:logdir])
    @file = File.open("#{opt[:logdir]}/#{opt[:logfile]}",'w')
    @sync = Sync.new
    
    profile('Starting Up')
  end

  def calculate_delta(curr, prev)
    delta = Hash.new(0)

    curr.each_key do |k|
        delta[k] = curr[k].length - prev[k].length
    end
    delta
  end

  def calculate_retained(curr, prev)
    retained = Hash.new(0)

    curr.each_key do |k|
        retained[k] = curr[k] - prev[k]
    end
    retained
  end

  def profile(tag)
    file.puts(tag)
    file.puts(Time.now)
    
    curr.clear

    sync.synchronize(Sync::EX) do
      yield if block_given?

      GC.start

      ObjectSpace.each_object do |o|
        curr[o.class] << o.object_id 
      end
    end

    if opt[:deltas]
        file.puts "Deltas"

        calculate_delta(curr, prev).select { |k,v| v != 0 }.sort_by { |k,v| -v }.each do |k,v|
            file.printf "%+5d: %s (%d)\n", v, k.name, curr[k].length
        end
        
        file.puts "\n\n"
    end

    if opt[:retained]
        file.puts "Top 20 retained"

        calculate_retained(curr, prev).sort { |a,b| b[1].length <=> a[1].length }[0..19].each do |klass, common|
            file.puts "%s: %s/%s (%0.2f)" % [klass, common.length, curr[klass].length, common.length.to_f/curr[klass].length.to_f] if common.length > 0
        end

        file.puts "\n\n"
    end
    
    file.flush

    prev.clear
    prev.update curr
  end
end
