include_recipe "hops::wrap"
include_recipe "hadoop::rm"


my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")
rm_dest_ip = rm_private_ip

ndb_connectstring()

template "#{node[:hadoop][:home]}/etc/hadoop/RM_EventAPIConfig.ini" do 
  source "RM_EventAPIConfig.ini.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connectstring]
            })
end

template "#{node[:hadoop][:home]}/etc/hadoop/RT_EventAPIConfig.ini" do 
  source "RT_EventAPIConfig.ini.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connectstring]
            })
end



container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node[:hadoop][:cgroups].eql? "true" 
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end


template "#{node[:hadoop][:home]}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node[:hadoop][:yarn][:user]
  group node[:hadoop][:group]
  mode "666"
  variables({
              :rm_private_ip => rm_dest_ip,
              :rm_public_ip => rm_public_ip,
              :available_mem_mb => node[:hadoop][:yarn][:nm][:memory_mbs],
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :container_executor => container_executor
            })
  action :create_if_missing
end
