require 'puppet/util/user_attr'

Puppet::Type.type(:user).provide :user_role_add, :parent => Puppet::Type::User::ProviderUseradd do

    desc "User management inherits ``useradd`` and adds logic to manage roles on Solaris using roleadd." 

    defaultfor :operatingsystem => :solaris

    commands :add => "useradd", :delete => "userdel", :modify => "usermod", :role_add => "roleadd", :role_delete => "roledel", :role_modify => "rolemod"
    options :home, :flag => "-d", :method => :dir
    options :comment, :method => :gecos
    options :groups, :flag => "-G"
    options :roles, :flag => "-R"

    verify :gid, "GID must be an integer" do |value|
        value.is_a? Integer
    end

    verify :groups, "Groups must be comma-separated" do |value|
        value !~ /\s/
    end

    has_features :manages_homedir, :allows_duplicates, :manages_solaris_rbac

    if Puppet.features.libshadow?
        has_feature :manages_passwords
    end

    def user_attributes
        @user_attributes ||= UserAttr.get_attributes_by_name(@resource[:name])
    end

    def flush
        @user_attributes = nil
    end

    def command(cmd)
        if is_role? or (!exists? and @resource[:ensure] == :role)
            cmd = ("role_" + cmd.to_s).intern
        end
        super(cmd)
    end

    def is_role?
        user_attributes and user_attributes[:type] == "role"
    end

    def run(cmd, msg)
        begin
            execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not %s %s %s: %s" %
                [msg, @resource.class.name, @resource.name, detail]
        end
    end

    def transition_to_user_cmd
        #note: this will really get the role command
        cmd = [command(:modify)]
        cmd << "-K" << "type=normal"
        cmd << @resource[:name]
    end

    def transition_to_role_cmd
        cmd = [command(:modify)]
        cmd << "-K" << "type=role"
        cmd << @resource[:name]
    end

    def create
        if !exists?
            run(addcmd, "create")
        elsif is_role?
            run(transition_to_user_cmd, "transition role to")
        else
            info "already exists"
        end
    end

    def destroy
        if exists?
            run(deletecmd, "delete "+ (is_role? ? "role" : "user"))
        else
            info "already absent" 
        end
    end

    def create_role
        if !exists?
            run(addcmd, "create role")
        elsif !is_role?
            run(transition_to_role_cmd, "transition user to")
        else
            info "role already exists"
        end
    end

    def roles
        if user_attributes
            user_attributes[:roles]
        end
    end
end

