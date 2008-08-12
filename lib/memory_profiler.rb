
class MemoryProfiler
  DEFAULTS = {
      :delay => 10, :string_debug => true, :retained => true, :deltas => true, :logdir => "/tmp/memory_log",
      :rrdtool => false, :array_debug => true
  }

  def self.start(opt={})
    opt = DEFAULTS.dup.merge(opt)

    Dir.mkdir(opt[:logdir]) unless File.directory?(opt[:logdir])

    Thread.new do
      curr_strings = []
      delta = Hash.new(0)
      curr = Hash.new { |hash, key| hash[key] = [] }
      prev = Hash.new { |hash, key| hash[key] = [] }
      watched = Hash.new { |hash, key| hash[key] = [] }
      retained = Hash.new(0)

      file = File.open("#{opt[:logdir]}/memory_profiler_#{Time.now.to_i}.log",'a+')

      loop do
        begin
          GC.start
          curr.clear

          curr_strings = [] if opt[:string_debug]

          string_file = File.open("#{opt[:logdir]}/memory_profiler_strings.log.#{Time.now.to_i}",'w') if opt[:string_debug]

          ObjectSpace.each_object do |o|
            id = o.object_id
            curr[o.class] << id #Marshal.dump(o).size rescue 1
            string_file.puts(o) if opt[:string_debug] and o.class == String

            if opt[:array_debug] and o.class == Array
                next unless o.length > 2000
                next if curr.has_value?(o)
                next if retained.has_value?(o)
                next if prev.has_value?(o)

                file.puts "%s: %s" % [o.length, o[0..10].inspect]

                o.freeze if o.length > 20000
            end
          end

          string_file.close if opt[:string_debug]


          if opt[:deltas]
              (curr.keys + delta.keys).uniq.each do |k,v|
                  delta[k] = curr[k].length - prev[k].length
              end
              file.puts "Top 20"
              delta.sort_by { |k,v| -v.abs }[0..19].sort_by { |k,v| -v}.each do |k,v|
                  file.printf "%+5d: %s (%d)\n", v, k.name, curr[k].length unless v == 0
              end
              file.puts "\n\n"
              delta.clear
          end

          if opt[:retained]
              file.puts "Top 20 retained"
              total = 0
              (curr.keys + prev.keys).uniq.each do |k,v|
                  retained[k] = prev[k].find_all { |v| curr[k].include?(v) }
              end
              retained.sort { |a,b| b[1].length <=> a[1].length }.each do |klass, common|
                  total += 1
                  file.puts "%s: %s/%s (%0.2f)" % [klass, common.length, curr[klass].length, common.length.to_f/curr[klass].length.to_f] if common.length > 0
                  break if total > 20
              end

              file.puts "\n\n"
              retained.clear
          end

          file.flush

          prev.clear
          prev.update curr
          GC.start
        rescue Exception => err
            puts err.backtrace
          STDERR.puts "** memory_profiler error: #{err}"
        end
        sleep opt[:delay]
      end
    end
  end
end
