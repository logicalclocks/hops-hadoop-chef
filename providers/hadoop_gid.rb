require 'etc'

action :set do 
    # Get the current hadoop group id
    ruby_block 'get current hadaoop gid' do
        block do
            old_gid = Etc.getgrnam(new_resource.group_name).gid.to_s  
        end
        action :run
    end

    # delete force will remove the group even if it's the primary group of some users
    # primary groups will be fixed later on by the other recipes
    bash 'delete force hadoop group' do 
        user 'root'
        code <<-EOF
            groupdel -f #{new_resource.group_name}
        EOF
    end
    
    # Create the new group 
    # we need to fix the gid to match the one in the docker image
    group new_resource.group_name do 
        gid new_resource.group_id
        action :create
    end

    # We need to change the group id to all the files in /srv/hops
    bash 'chgrp files' do
        user 'root'
        code <<-EOF
            find #{new_resource.install_dir} -group #{old_gid} -exec chgrp #{new_resource.gropu_name} {} \;
        EOF
    end
end