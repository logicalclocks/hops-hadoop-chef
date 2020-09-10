include_recipe "hops::default"

# Proxyserver and NodeManager run as the same user
# Generate certificate only once
unless exists_local("hops", "nm")
  crypto_dir = x509_helper.get_crypto_dir(node['hops']['yarn']['user'])
  kagent_hopsify "Generate x.509" do
    user node['hops']['yarn']['user']
    crypto_directory crypto_dir
    action :generate_x509
    not_if { node["kagent"]["enabled"] == "false" }
  end
end

yarn_service="ps"
service_name="proxyserver"

for script in node['hops']['yarn']['scripts']
  template "#{node['hops']['sbin_dir']}/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node['hops']['yarn']['user']
    group node['hops']['secure_group']
    mode 0750
  end
end 

# hop_yarn_services node['hops']['services'] do
#   action "install_#{yarn_service}"
# end

if node['hops']['systemd'] == "true"

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  case node['platform_family']
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  else
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
if node['services']['enabled'] == "true"
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
    owner node['hops']['yarn']['user']
    group node['hops']['group']
    mode 0755            
if node['services']['enabled'] == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, resources(:service => service_name)
  end

end

if node['kagent']['enabled'] == "true" 
  kagent_config service_name do
    service "YARN"
    start_script "#{node['hops']['home']}/sbin/start-#{yarn_service}.sh"
    stop_script "#{node['hops']['home']}/sbin/stop-#{yarn_service}.sh"
    log_file "#{node['hops']['logs_dir']}/yarn-#{node['hops']['hdfs']['user']}-#{service_name}-#{node['hostname']}.log"
    pid_file "#{node['hops']['logs_dir']}/yarn-#{node['hops']['hdfs']['user']}-#{service_name}.pid"
  end
end

