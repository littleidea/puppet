#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:user).provider(:user_role_add)

describe provider_class do
    before do
        @resource = stub("resource", :name => "myuser", :managehome? => nil)
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @resource.stubs(:allowdupe?).returns false 
        @provider = provider_class.new(@resource)
    end

    describe "when calling command" do
        before do
            klass = stub("provider")
            klass.stubs(:command).with(:foo).returns("userfoo")
            klass.stubs(:command).with(:role_foo).returns("rolefoo")
            @provider.stubs(:class).returns(klass)
        end

        it "should use the command if not a role" do
            @provider.stubs(:is_role?).returns(false)
            @provider.command(:foo).should == "userfoo"
        end

        it "should use the role command when a role" do
            @provider.stubs(:is_role?).returns(true)
            @provider.command(:foo).should == "rolefoo"
        end
    end

    describe "when calling transition_to_user_cmd" do
        it "should return rolemod setting the type to normal" do
            @provider.expects(:command).with(:role_modify).returns("rolemod")
            @provider.transition_to_user_cmd.should == ["rolemod", "-K", "type=normal", "fakeval"]
        end
    end

    describe "when calling transition_to_role_cmd" do
        it "should return usermod setting the type to role" do
            @provider.expects(:command).with(:modify).returns("usermod")
            @provider.transition_to_role_cmd.should == ["usermod", "-K", "type=role", "fakeval"]
        end
    end

    describe "when calling create" do
        it "should use the add command when the user doesn't exist" do
            @provider.stubs(:exists?).returns(false)
            @provider.expects(:addcmd).returns("useradd")
            @provider.expects(:run)
            @provider.create
        end

        it "should use transition_to_user_cmd when the user is a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(true)
            @provider.expects(:transition_to_user_cmd)
            @provider.expects(:run)
            @provider.create
        end

        it "should log to info when the user exists and is not a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:info).with("already exists")
            @provider.create
        end
    end

   describe "when calling destroy" do
       it "should use the delete command if the user exists and is not a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:deletecmd)
            @provider.expects(:run)
            @provider.destroy
       end

       it "should use the delete command if the user is a role" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(true)
            @provider.expects(:deletecmd)
            @provider.expects(:run)
            @provider.destroy
       end

       it "should log to info if the user doesn't exist" do
            @provider.stubs(:exists?).returns(false)
            @provider.expects(:info).with("already absent")
            @provider.destroy
       end
   end

   describe "when calling create_role" do
       it "should use the transition_to_role_cmd if the user exists" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(false)
            @provider.expects(:transition_to_role_cmd)
            @provider.expects(:run)
            @provider.create_role
       end

       it "should use the add command role doesn't exists" do
            @provider.stubs(:exists?).returns(false)
            @provider.expects(:addcmd)
            @provider.expects(:run)
            @provider.create_role
       end
       
       it "should log to info if the role exists" do
            @provider.stubs(:exists?).returns(true)
            @provider.stubs(:is_role?).returns(true)
            @provider.expects(:info).with("role already exists")
            @provider.create_role
       end
   end

    describe "when allow duplicate is enabled" do 
        before do
            @resource.expects(:allowdupe?).returns true
            @provider.expects(:execute).with { |args| args.include?("-o") }
        end

        it "should add -o when the user is being created" do
            @provider.create
        end
    
        it "should add -o when the uid is being modified" do
            @provider.uid = 150
        end
    end
end
