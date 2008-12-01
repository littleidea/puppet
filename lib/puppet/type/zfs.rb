module Puppet
    newtype(:zfs) do
        @doc = "Manage zfs. Create destroy and set properties on zfs instances."

        ensurable

        newparam(:zfs) do
            desc "The full name for this filesystem. (including the zpool)"
            isnamevar
        end

        newproperty(:mountpoint) do
            desc "The mountpoint property."
        end

        newproperty(:compression) do
            desc "The compression property."
        end

        newproperty(:copies) do
            desc "The copies property."
        end

        newproperty(:quota) do
            desc "The quota property."
        end

        newproperty(:reservation) do
            desc "The reservation property."
        end

        newproperty(:sharenfs) do
            desc "The sharenfs property."
        end

        newproperty(:snapdir) do
            desc "The sharenfs property."
        end

        autorequire(:zpool) do
            #strip the zpool off the zfs name and autorequire it
            [@parameters[:zfs].value.split('/')[0]]
        end
    end
end

