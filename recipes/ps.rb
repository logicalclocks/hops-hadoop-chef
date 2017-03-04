case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.hops.systemd = "false"
 end
end

yarn_service="ps"
service_name="proxyserver"

for script in node.hops.yarn.scripts
  template "#{node.hops.home}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node.hops.yarn.user
    group node.hops.group
    mode 0775
  end
end 

# hop_yarn_services node.hops.services do
#   action "install_#{yarn_service}"
# end

if node.hops.systemd == "true"

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
    owner node.hops.yarn.user
    group node.hops.group
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
    start_script "#{node.hops.home}/sbin/root-start-#{yarn_service}.sh"
    stop_script "#{node.hops.home}/sbin/stop-#{yarn_service}.sh"
    log_file "#{node.hops.logs_dir}/yarn-#{node.hops.hdfs.user}-#{service_name}-#{node.hostname}.log"
    pid_file "#{node.hops.logs_dir}/yarn-#{node.hops.hdfs.user}-#{service_name}.pid"
    web_port node.hops["#{yarn_service}"][:http_port]
  end
end

