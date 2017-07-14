action :create do
  Chef::Log.info "Creating hdfs directory: #{@new_resource.name}"

  recursive="-p"
  if new_resource.recursive == false
      recursive=""
  end
  bash "mk-dir-#{new_resource.name}" do
    user "#{new_resource.owner}"
    group "#{new_resource.group}"
    code <<-EOF
     . #{node.hops.base_dir}/sbin/set-env.sh
     #{node.hops.base_dir}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     if [ $? -ne 0 ] ; then 
        sleep 10
        #{node.hops.base_dir}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     fi
     #{node.hops.base_dir}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.name}
     if [ "#{new_resource.mode}" != "" ] ; then
        #{node.hops.base_dir}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.name} 
     fi
    EOF
  not_if "su -c #{new_resource.owner} \". #{node.hops.base_dir}/sbin/set-env.sh && #{node.hops.base_dir}/bin/hdfs dfs -test -d #{new_resource.name}\""
  end
 
end

action :put do
  Chef::Log.info "Putting file(s) from directory #{@new_resource.name} into hdfs directory #{@new_resource.dest}"

  bash "hdfs-put-dir-#{new_resource.name}" do
    user "#{new_resource.owner}"
    group "#{new_resource.group}"    
    code <<-EOF
     . #{node.hops.base_dir}/sbin/set-env.sh
     #{node.hops.base_dir}/bin/hdfs dfs -test -e #{new_resource.dest}
     if [ $? -ne 0 ] ; then
        #{node.hops.base_dir}/bin/hdfs dfs -copyFromLocal #{new_resource.name} #{new_resource.dest}
        #{node.hops.base_dir}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.dest}
        if [ "#{new_resource.mode}" != "" ] ; then
           #{node.hops.base_dir}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.dest} 
        fi
     fi
    EOF
  end
 
end


action :put_as_superuser do
  Chef::Log.info "Putting file(s) #{@new_resource.isDir} from directory #{@new_resource.name} into hdfs directory #{@new_resource.dest}"

  bash "hdfs-put-dir-#{new_resource.name}" do
    user node.hops.hdfs.user
    group node.hops.group
    code <<-EOF
     EXISTS = 1
     . #{node.hops.base_dir}/sbin/set-env.sh
     if [ -z $ISDIR ] ; then
        #{node.hops.base_dir}/bin/hdfs dfs -test -e #{new_resource.dest}
        $EXISTS = $?
     fi
     if ([ $EXISTS -ne 0 ] || [ #{new_resource.isDir} ]) ; then
        #{node.hops.base_dir}/bin/hdfs dfs -copyFromLocal #{new_resource.name} #{new_resource.dest}
        #{node.hops.base_dir}/bin/hdfs dfs -chown #{new_resource.owner} #{new_resource.dest}
        #{node.hops.base_dir}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.dest}
        if [ "#{new_resource.mode}" != "" ] ; then
           #{node.hops.base_dir}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.dest}
        fi
     fi
    EOF
  end

end


action :create_as_superuser do
  Chef::Log.info "Creating hdfs directory: #{@new_resource.name}"

  recursive="-p"
  if new_resource.recursive == false
      recursive=""
  end

  bash "mk-dir-#{new_resource.name}" do
    user node.hops.hdfs.user
    group node.hops.group
    code <<-EOF
     . #{node.hops.base_dir}/sbin/set-env.sh
     #{node.hops.base_dir}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     if [ $? -ne 0 ] ; then 
        sleep 10
        #{node.hops.base_dir}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     fi
     #{node.hops.base_dir}/bin/hdfs dfs -chown #{new_resource.owner} #{new_resource.name}
     #{node.hops.base_dir}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.name}
     if [ "#{new_resource.mode}" != "" ] ; then
        #{node.hops.base_dir}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.name} 
     fi
    EOF
  not_if "su #{node.hops.hdfs.user} -c \". #{node.hops.base_dir}/sbin/set-env.sh && #{node.hops.base_dir}/bin/hdfs dfs -test -d #{new_resource.name}\""
  end
 
end
