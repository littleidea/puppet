#!/usr/bin/env ruby
# 
# Unit testing for the launchd service provider
#

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:service).provider(:launchd)

describe provider_class do

    before :each do
        # Create a mock resource
        @resource = stub 'resource'
        @provider = provider_class.new
        @joblabel = "com.foo.food"

        # A catch all; no parameters set
        @resource.stubs(:[]).returns(nil)

        # But set name, ensure and enable
        @resource.stubs(:[]).with(:name).returns @joblabel
        @resource.stubs(:[]).with(:ensure).returns :enabled
        @resource.stubs(:[]).with(:enable).returns :true
        @resource.stubs(:ref).returns "Service[#{@joblabel}]"

        # why is this not working?
        @provider.stubs(:plist_from_label).returns([@joblabel, 1])
        
        @provider.stubs(:resource).returns @resource
        @provider.stubs(:enabled?).returns :true
    end

    it "should have a start method" do
        @provider.should respond_to(:start)
    end

    it "should have a stop method" do
        @provider.should respond_to(:stop)
    end

    it "should have an enabled? method" do
        @provider.should respond_to(:enabled?)
    end

    it "should have an enable method" do
        @provider.should respond_to(:enable)
    end

    it "should have a disable method" do
        @provider.should respond_to(:disable)
    end
    
    it "should have a status method" do
        @provider.should respond_to(:status)
    end
    
    
    describe "when checking status" do
        it "should execute launchctl list" do
            @provider.stubs(:plist_from_label).returns([@joblabel, 1])
            @provider.expects(:launchctl).with(:list).returns(:stopped)
            @provider.status
        end
    end
    
 end
