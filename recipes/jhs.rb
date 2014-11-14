include_recipe "hops::yarn"
libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')

yarn_service="jhs"
yarn_command="historyserver"

for script in node[:hadoop][:yarn][:scripts]
  template "#{node[:hadoop][:home]}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node[:hadoop][:yarn][:user]
    group node[:hadoop][:group]
    mode 0775
  end
end 

service yarn_command do
  supports :restart => true, :stop => true, :start => true
  action :nothing
end

template "/etc/init.d/#{yarn_command}" do
  source "#{yarn_command}.erb"
  owner node[:hadoop][:yarn][:user]
  group node[:hadoop][:group]
  mode 0754
  notifies :enable, resources(:service => yarn_command)
  notifies :restart, resources(:service => yarn_command)
end

user node[:hadoop][:mr][:user] do
  supports :manage_home => true
  home "/home/#{node[:hadoop][:mr][:user]}"
  action :create
  system true
  shell "/bin/bash"
end

group node[:hadoop][:group] do
  action :modify
  members node[:hadoop][:mr][:user]
  append true
end

kagent_config yarn_command do
  service "MAP_REDUCE"
  start_script "#{node[:hadoop][:home]}/sbin/root-start-#{yarn_service}.sh"
  stop_script "#{node[:hadoop][:home]}/sbin/stop-#{yarn_service}.sh"
  log_file "#{node[:hadoop][:logs_dir]}/yarn-#{node[:hdfs][:user]}-#{yarn_command}-#{node['hostname']}.log"
#  pid_file "#{node[:hadoop][:logs_dir]}/yarn-#{node[:hdfs][:user]}-#{yarn_command}.pid"
  pid_file "/tmp/mapred-#{node[:hdfs][:user]}-#{yarn_command}.pid"
  config_file "#{node[:hadoop][:conf_dir]}/mapred-site.xml"
  web_port node[:hadoop]["#{yarn_service}"][:http_port]
end
