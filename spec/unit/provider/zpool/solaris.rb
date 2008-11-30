#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:zpool).provider(:solaris)

describe provider_class do
    before do
        @resource = stub("resource", :name => "mypool")
        @resource.stubs(:[]).returns "shouldvalue"
        @provider = provider_class.new(@resource)
    end

    describe "when getting the instance" do
        before do
            #get pool data is untested voodoo at the moment
            @provider.stubs(:get_pool_data).returns(["foo", "disk"])
        end

        it "should call process_zpool_data with the result of get_pool_data" do
            @provider.expects(:process_zpool_data).with(["foo", "disk"])
            @provider.get_instance
        end
    end

    describe "when procesing zpool data" do
        before do
            @zpool_data = ["foo", "disk"]
        end

        describe "when there is no data" do
            it "should return a hash with ensure=>:absent" do
                @provider.process_zpool_data([])[:ensure].should == :absent
            end
        end

        describe "when there is a spare" do
            it "should add the spare disk to the hash and strip the array" do
                @zpool_data += ["spares", "spare_disk"]
                pool = @provider.process_zpool_data(@zpool_data)
                pool[:spare].should == ["spare_disk"]

                #test the side effects
                @zpool_data.should == ["disk"]
            end
        end

        describe "when there is a log" do
            it "should add the log disk to the hash and strip the array" do
                @zpool_data += ["logs", "log_disk"]
                @provider.process_zpool_data(@zpool_data)[:log].should == ["log_disk"]

                #test the side effects
                @zpool_data.should == ["disk"]
            end
        end

        describe "when the vdev is a mirror" do
            it "should call create_multi_array with mirror" do
                @zpool_data = ["mirrorpool", "mirror", "disk1", "disk2"]
                @provider.expects(:create_multi_array).with("mirror", ["mirror", "disk1", "disk2"])
                @provider.process_zpool_data(@zpool_data)
            end
        end

        describe "when the vdev is a raidz1" do
            it "should call create_multi_array with raidz1" do
                @zpool_data = ["mirrorpool", "raidz1", "disk1", "disk2"]
                @provider.expects(:create_multi_array).with("raidz1", ["raidz1", "disk1", "disk2"])
                @provider.process_zpool_data(@zpool_data)
            end
        end

        describe "when the vdev is a raidz2" do
            it "should call create_multi_array with raidz2 and set the raid_parity" do
                @zpool_data = ["mirrorpool", "raidz2", "disk1", "disk2"]
                @provider.expects(:create_multi_array).with("raidz2", ["raidz2", "disk1", "disk2"])
                @provider.process_zpool_data(@zpool_data)[:raid_parity].should == "raidz2"
            end
        end
    end

    describe "when calling create_multi_array" do
        it "should concatenate and tokenize by the 'type'" do
            array = ["type", "disk1", "disk2", "type", "disk3", "disk4"]
            @provider.create_multi_array("type", array).should == ["disk1 disk2", "disk3 disk4"]
        end
    end

    describe "when calling the getters and setters" do
        [:disk, :mirror, :raidz, :log, :spare].each do |field|
            describe "when calling %s" % field do
                it "should get the %s value from the current_pool hash" % field do
                    pool_hash = mock "pool hash"
                    pool_hash.expects(:[]).with(field)
                    @provider.stubs(:current_pool).returns(pool_hash)
                    @provider.send(field)
                end
            end

            describe "when setting the %s" % field do
                it "should warn the %s values were not in sync" % field do
                    Puppet.expects(:warning).with("zpool %s does not match, should be 'shouldvalue' currently is 'currentvalue'" % field)
                    @provider.stubs(:current_pool).returns(Hash.new("currentvalue"))
                    @provider.send((field.to_s + "=").intern, "shouldvalue")
                end
            end
        end
    end

    describe "when calling build_create_cmd" do
        before do
            @provider.stubs(:build_named).returns([])
            @resource.stubs(:[]).with(:pool).returns("this_pool")
        end

        it "should return an array with the first two entries as :create and the name of the pool" do
            array = @provider.build_create_cmd
            array[0].should == :create
            array[1].should == "this_pool"
        end

        it "should call build_vdevs" do
            @provider.expects(:build_vdevs).returns([])
            @provider.build_create_cmd
        end

        it "should call build_named with 'spares'" do
            @provider.expects(:build_named).with("spare").returns([])
            @provider.build_create_cmd
        end

        it "should call build_named with 'logs'" do
            @provider.expects(:build_named).with("log").returns([])
            @provider.build_create_cmd
        end
    end

    describe "when calling create" do
        it "should call zpool with arguments from build_create_cmd" do
            @provider.stubs(:build_create_cmd).returns(["a", "bunch", "of", "stuff"])
            @provider.expects(:zpool).with("a", "bunch", "of", "stuff")
            @provider.create
        end
    end

    describe "when calling delete" do
        it "should call zpool with destroy and the pool name" do
            @resource.stubs(:[]).with(:pool).returns("poolname")
            @provider.expects(:zpool).with(:destroy, "poolname")
            @provider.delete
        end
    end

    describe "when calling exists?" do
        before do
            @current_pool = Hash.new(:absent)
            @provider.stubs(:current_pool).returns(@current_pool)
            @provider.stubs(:get_instance)
        end

        it "should get the current pool" do
            @provider.expects(:get_instance)
            @provider.exists?
        end

        it "should return false if the current_pool is absent" do
            #the before sets it up
            @provider.exists?.should == false
        end

        it "should return true if the current_pool has values" do
            @current_pool[:pool] = "mypool"
            @provider.exists?.should == true
        end
    end
end
