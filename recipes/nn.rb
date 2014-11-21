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

template "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => firstNN,
              :listNNs => allNNs
            })
end

for script in node[:hadoop][:nn][:scripts]
  template "#{node[:hadoop][:home]}/sbin/#{script}" do
    source "#{script}.erb"
    owner node[:hdfs][:user]
    group node[:hadoop][:group]
    mode 0775
  end
end 


# it is ok if all namenodes format the fs. Unless you add a new one later..
if node[:hadoop][:format].eql? "true"
  if ::File.directory?("#{node[:hadoop][:tmp_dir]}/dfs/data/current/")
    # if the nn has already been formatted, re-formatting it returns error
    Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node[:hadoop][:tmp_dir]}/dfs/data/current/)"
  else 
    bash 'format-nn' do
      user node[:hdfs][:user]
      code <<-EOH
   	#{node[:hadoop][:home]}/sbin/format-nn.sh
 	EOH
    end
  end
end

service "namenode" do
  supports :restart => true, :stop => true, :start => true
  action :nothing
end

template "/etc/init.d/namenode" do
  source "namenode.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode 0754
  notifies :enable, resources(:service => "namenode"), :immediately
  notifies :restart, resources(:service => "namenode")
end

kagent_config "namenode" do
  service "HDFS"
  start_script "#{node[:hadoop][:home]}/sbin/root-start-nn.sh"
  stop_script "#{node[:hadoop][:home]}/sbin/stop-nn.sh"
  init_script "#{node[:hadoop][:home]}/sbin/format-nn.sh"
  config_file "#{node[:hadoop][:conf_dir]}/core-site.xml"
  log_file "#{node[:hadoop][:logs_dir]}/hadoop-#{node[:hdfs][:user]}-namenode-#{node['hostname']}.log"
  pid_file "#{node[:hadoop][:logs_dir]}/hadoop-#{node[:hdfs][:user]}-namenode.pid"
  web_port node[:hadoop][:nn][:http_port]
end

