include_recipe "hops::wrap"
include_recipe "apache_hadoop::rm"


my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")
rm_dest_ip = rm_private_ip

ndb_connectstring()

template "#{node.apache_hadoop.home}/etc/hadoop/RM_EventAPIConfig.ini" do 
  source "RM_EventAPIConfig.ini.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  variables({
              :ndb_connectstring => node.ndb.connectstring
            })
end

template "#{node.apache_hadoop.home}/etc/hadoop/RT_EventAPIConfig.ini" do 
  source "RT_EventAPIConfig.ini.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  variables({
              :ndb_connectstring => node.ndb.connectstring
            })
end



container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node.apache_hadoop.cgroups.eql? "true" 
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end

file "#{node.apache_hadoop.home}/etc/hadoop/yarn-site.xml" do 
  owner node.apache_hadoop.hdfs.user
  action :delete
end

template "#{node.apache_hadoop.home}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node.apache_hadoop.yarn.user
  group node.apache_hadoop.group
  mode "666"
  variables({
              :rm_private_ip => rm_dest_ip,
              :rm_public_ip => rm_public_ip,
              :available_mem_mb => node.apache_hadoop.yarn.nm.memory_mbs,
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :container_executor => container_executor
            })
  action :create_if_missing
end


# TODO: This is a hack - sometimes the nn fails during install. If so, just restart it.

service_name="resourcemanager"
if node.apache_hadoop.systemd == "true"
  service "#{service_name}" do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end
else  #sysv
  service "#{service_name}" do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end
end
