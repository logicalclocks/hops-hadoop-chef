include_recipe "apache_hadoop::yarn"

yarn_service="ps"
service_name="proxyserver"

for script in node.apache_hadoop.yarn.scripts
  template "#{node.apache_hadoop.home}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node.apache_hadoop.yarn.user
    group node.apache_hadoop.group
    mode 0775
  end
end 

# hop_yarn_services node.apache_hadoop.services do
#   action "install_#{yarn_service}"
# end

if node.apache_hadoop.systemd == "true"

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  case node.platform_family
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  else
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
if node.services.enabled == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, "service[#{service_name}]"
  end




else # sysv

  service service_name do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  template "/etc/init.d/#{service_name}" do
    source "#{service_name}.erb"
    owner node.apache_hadoop.yarn.user
    group node.apache_hadoop.group
    mode 0754
if node.services.enabled == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, resources(:service => service_name)
  end

end

if node.kagent.enabled == "true" 
  kagent_config service_name do
    service "YARN"
    start_script "#{node.apache_hadoop.home}/sbin/root-start-#{yarn_service}.sh"
    stop_script "#{node.apache_hadoop.home}/sbin/stop-#{yarn_service}.sh"
    log_file "#{node.apache_hadoop.logs_dir}/yarn-#{node.apache_hadoop.hdfs.user}-#{service_name}-#{node.hostname}.log"
    pid_file "#{node.apache_hadoop.logs_dir}/yarn-#{node.apache_hadoop.hdfs.user}-#{service_name}.pid"
    web_port node.apache_hadoop["#{yarn_service}"][:http_port]
  end
end

