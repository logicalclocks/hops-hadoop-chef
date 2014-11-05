libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')
require 'resolv'

set_hostnames("hops", "nn")
set_hostnames("hops", "dn")
ndb_connectstring()
#nnPort=29211
nnPort=9000

allNNs = ""
for nn in private_recipe_hostnames("hops","nn")
#for nn in node[:hadoop][:nn][:private_ips]
   allNNs += "hdfs://" + "#{nn}" + ":#{nnPort},"
end
firstNN = allNNs.eql?("") ? "" : allNNs.split(",").first

# nnPort=29211
# firstNnIp = private_recipe_ip('hop', 'nn')
# firstNN = "hdfs://" + firstNnIp + ":" + "#{nnPort}"
# allNNs = "hdfs://" + node[:hadoop][:nn][:private_ips].join(":" + "#{nnPort}" + ",hdfs://") + ":" + "#{nnPort}"

template "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => firstNN,
              :listNNs => allNNs
            })
end

for script in node[:hadoop][:dn][:scripts]
  template "#{node[:hadoop][:home]}/sbin/#{script}" do
    source "#{script}.erb"
    owner node[:hadoop][:user]
    group node[:hadoop][:group]
    mode 0775
  end
end 


service "datanode" do
  supports :restart => true, :stop => true, :start => true
  action :nothing
end

template "/etc/init.d/datanode" do
  source "datanode.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode 0754
  notifies :enable, resources(:service => "datanode")
  notifies :restart, resources(:service => "datanode"), :immediately
end


kagent_config "datanode" do
  service "HDFS"
  start_script "#{node[:hadoop][:home]}/sbin/root-start-dn.sh"
  stop_script "#{node[:hadoop][:home]}/sbin/stop-dn.sh"
  log_file "#{node[:hadoop][:logs_dir]}/hadoop-#{node[:hadoop][:user]}-datanode-#{node['hostname']}.log"
  pid_file "#{node[:hadoop][:logs_dir]}/hadoop-#{node[:hadoop][:user]}-datanode.pid"
  config_file "#{node[:hadoop][:conf_dir]}/hdfs-site.xml"
  web_port node[:hadoop][:dn][:http_port]
  command "hdfs"
  command_user node[:hadoop][:user]
  command_script "#{node[:hadoop][:home]}/bin/hdfs"
end
