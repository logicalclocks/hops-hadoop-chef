
action :create do
  Chef::Log.info "Creating hdfs directory: #{@new_resource}"
  Chef::Log.info "Creating hdfs directory: #{@new_resource.name}"

  bash "mk-dir-#{new_resource.name}" do
    user node[:hdfs][:user]
    code <<-EOF
     . #{node[:hadoop][:home]}/sbin/set-env.sh
     #{node[:hadoop][:home]}/bin/hdfs dfs -mkdir -p #{new_resource.name}
     #{node[:hadoop][:home]}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.name} 
    EOF
    not_if ". #{node[:hadoop][:home]}/sbin/set-env.sh && #{node[:hadoop][:home]}/bin/hdfs dfs -test -d #{new_resource.name}"
  end
 
end
