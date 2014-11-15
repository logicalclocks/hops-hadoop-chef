include_recipe "hops::yarn"
libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')

ndb_connectstring()

yarn_service="rm"
yarn_command="resourcemanager"

for script in node[:hadoop][:yarn][:scripts]
  template "#{node[:hadoop][:home]}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node[:hadoop][:yarn][:user]
    group node[:hadoop][:group]
    mode 0775
  end
end 

template "#{node[:hadoop][:home]}/sbin/yarn.sh" do
  source "yarn.sh.erb"
  owner node[:hadoop][:yarn][:user]
  group node[:hadoop][:group]
  mode 0775
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
  notifies :restart, "service[#{yarn_command}]"
end

kagent_config yarn_command do
  service "YARN"
  start_script "#{node[:hadoop][:home]}/sbin/root-start-#{yarn_service}.sh"
  stop_script "#{node[:hadoop][:home]}/sbin/stop-#{yarn_service}.sh"
  log_file "#{node[:hadoop][:logs_dir]}/yarn-#{node[:hadoop][:yarn][:user]}-#{yarn_command}-#{node['hostname']}.log"
  pid_file "#{node[:hadoop][:logs_dir]}/yarn-#{node[:hadoop][:yarn][:user]}-#{yarn_command}.pid"
  config_file "#{node[:hadoop][:conf_dir]}/yarn-site.xml"
  web_port node[:hadoop]["#{yarn_service}"][:http_port]
  command "yarn"
  command_user node[:hadoop][:yarn][:user]
  command_script "#{node[:hadoop][:home]}/bin/yarn"
end
