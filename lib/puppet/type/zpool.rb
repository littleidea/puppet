module Puppet
    newtype(:zpool) do
        @doc = "Manage users.  This type is mostly built to manage system
            users, so it is lacking some features useful for managing normal
            users.

            This resource type uses the prescribed native tools for creating
            groups and generally uses POSIX APIs for retrieving information
            about them.  It does not directly modify /etc/passwd or anything."

        newproperty(:ensure, :parent => Puppet::Property::Ensure) do
            desc "Whether zpool should exist or not."
            newvalue(:present, :event => :pool_created) do
                provider.create
            end

            newvalue(:absent, :event => :pool_removed) do
                provider.delete
            end

            defaultto do
                if @resource.managed?
                    :present
                else
                    nil
                end
            end
        end

        newproperty(:disk, :array_matching => :all) do
            desc "The disk(s) for this pool."
        end

        newproperty(:mirror, :array_matching => :all) do
            desc "An array of arrays which list of all the devices to mirror for this pool."

            validate do |value|
                if value.include?(",")
                    raise ArgumentError, "Group names must be provided as an array, not a comma-separated list"
                end
            end
        end

        newproperty(:raidz, :array_matching => :all) do
            desc "An array of arrays which list of all the devices to raid for this pool."
        end

        newproperty(:spare, :array_matching => :all) do
            desc "Spare disk(s) for this pool."
        end

        newproperty(:log, :array_matching => :all) do
            desc "A disk for this pool. (doesn't support mirroring yet)"
        end

        newparam(:pool) do
            desc "The name for this pool"
            isnamevar
       end

        newparam(:raid_parity) do
            desc "determines parity if using zraid property"
        end

        validate do
            has_should = [:disk, :mirror, :raidz].select { |prop| self.should(prop) }
            if has_should.length > 1
                self.fail "You cannot specify %s on this type (only one)" % has_should.join(" and ")
            end
        end
    end
end

