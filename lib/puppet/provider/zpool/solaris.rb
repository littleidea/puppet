Puppet::Type.type(:zpool).provide(:solaris) do
    desc "Provider for Solaris zpool."

    commands :zpool => "/usr/sbin/zpool"
    defaultfor :operatingsystem => :solaris

    attr_reader :current_pool

    def create_multi_array(name, array)
        array = array.join(' ').split("#{name} ")
        array.shift
        array.collect { |a| a.strip }
    end

    def process_zpool_data(pool_array)
        if pool_array == []
            return Hash.new(:absent)
        end
        #get the name and get rid of it
        pool = { :pool => pool_array[0] }
        pool_array.shift

        #spares and logs will get the values and take them out of the array
        #order matters here and there are side effects on pool array :(
        if pool_array.include?("spares")
            pool[:spare] = pool_array.slice!(pool_array.index("spares")+1..pool_array.length-1)
            pool_array.pop
        end

        if pool_array.include?("logs")
            pool[:log] = pool_array.slice!(pool_array.index("logs")+1..pool_array.length-1)
            pool_array.pop
        end

        #all that should be left is the vdev data
        case pool_array[0]
            when "mirror"
                pool[:mirror] = create_multi_array("mirror", pool_array)
            when "raidz1"
                pool[:raidz] = create_multi_array("raidz1", pool_array)
            when "raidz2"
                pool[:raidz] = create_multi_array("raidz2", pool_array)
                pool[:raid_parity] = "raidz2"
            else
                pool[:disk] = pool_array
        end

        pool
    end

    def get_pool_data
        #this is all voodoo dependent on the output from zpool
        zpool_data = %x{ zpool status #{@resource[:pool]}}.split("\n").select { |line| line.index("\t") == 0 }.collect { |l| l.strip.split("\s")[0] }
        zpool_data.shift
        zpool_data
    end

    def get_instance
        @current_pool = process_zpool_data(get_pool_data)
    end

    #Adds log and spare
    def build_named(name)
        if prop = @resource[name.intern]
            [name] + prop.collect { |p| p.split(' ') }.flatten
        else
            []
        end
    end

    #query for parity and set the right string
    def raidzarity
        @resource[:raid_parity] ? @resource[:raid_parity] : "raidz1"
    end

    #handle mirror or raid
    def handle_multi_arrays(prefix, array)
        array.collect{ |a| [prefix] +  a.split(' ') }.flatten
    end

    #builds up the vdevs for create command
    def build_vdevs
        if disk = @resource[:disk]
            disk.collect { |d| d.split(' ') }.flatten
        elsif mirror = @resource[:mirror]
            handle_multi_arrays("mirror", mirror)
        elsif raidz = @resource[:raidz]
            handle_multi_arrays(raidzarity, raidz)
        end
    end

    def build_create_cmd
        [:create, @resource[:pool]] + build_vdevs + build_named("spare") + build_named("log")
    end

    def create
        zpool(*build_create_cmd)
    end

    def delete
        zpool :destroy, @resource[:pool]
    end

    def exists?
        get_instance
        if current_pool[:pool] == :absent
            false
        else
            true
        end
    end

    [:disk, :mirror, :raidz, :log, :spare].each do |field|
        define_method(field) do
            current_pool[field]
        end

        define_method(field.to_s + "=") do |should|
            Puppet.warning "zpool %s does not match, should be '%s' currently is '%s'" % [field, should, current_pool[field]]
        end
    end

end

