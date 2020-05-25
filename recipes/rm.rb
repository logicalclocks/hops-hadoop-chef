include_recipe "hops::default"

template_ssl_server()
ndb_connectstring()

template "#{node['hops']['conf_dir']}/rm-jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode "400"
end

deps = ""
if service_discovery_enabled()
  deps += "consul.service "
end
if exists_local("ndb", "mysqld")
  deps += "mysqld.service "
end

if node['hops']['tls']['crl_enabled'].casecmp?("true") and exists_local("hopsworks", "default")
  deps += "glassfish-domain1.service "
end

yarn_service="rm"
service_name="resourcemanager"

template "#{node['hops']['conf_dir']}/capacity-scheduler.xml" do
  source "capacity-scheduler.xml.erb"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode "644"
  action :create
end

for script in node['hops']['yarn']['scripts']
  template "#{node['hops']['home']}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node['hops']['rm']['user']
     group node['hops']['secure_group']
    mode 0750
  end
end

cookbook_file "#{node['hops']['conf_dir']}/resourcemanager.yaml" do 
  source "metrics/resourcemanager.yaml"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode 500
end

if node['hops']['systemd'] == "true"

  case node['platform_family']
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service"
  else
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  file systemd_script do
    action :delete
    ignore_failure true
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
    variables({
              :deps => deps
              })
if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, "service[#{service_name}]"
  end

  kagent_config "#{service_name}" do
    action :systemd_reload
    not_if "systemctl status resourcemanager"
  end

  directory "/etc/systemd/system/#{service_name}.service.d" do
    owner "root"
    group "root"
    mode "755"
    action :create
  end

  template "/etc/systemd/system/#{service_name}.service.d/limits.conf" do
    source "limits.conf.erb"
    owner "root"
    mode 0664
    action :create
  end

else #sysv

  service service_name do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  template "/etc/init.d/#{service_name}" do
    source "#{service_name}.erb"
    owner "root"
    group "root"
    mode 0755
if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, resources(:service => service_name)
  end



end

if node['kagent']['enabled'] == "true"
  kagent_config service_name do
    service "YARN"
    log_file "#{node['hops']['logs_dir']}/yarn-#{node['hops']['rm']['user']}-#{service_name}-#{node['hostname']}.log"
    config_file "#{node['hops']['conf_dir']}/yarn-site.xml"
  end
end

tmp_dirs   = [ "#{node['hops']['hdfs']['user_home']}/#{node['hops']['rm']['user']}"]
for d in tmp_dirs
  hops_hdfs_directory d do
    action :create_as_superuser
    owner node['hops']['rm']['user']
    group node['hops']['group']
    mode "1775"
  end
end

hops_hdfs_directory "#{node['hops']['hdfs']['user_home']}/#{node['hops']['yarn']['user']}" do
  action :create_as_superuser
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "1775"
end

hops_hdfs_directory node['hops']['yarn']['nodemanager']['remote_app_log_dir'] do
  action :create_as_superuser
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "1773"
end

if service_discovery_enabled()
  # Register ResourceManager with Consul
  template "#{node['hops']['bin_dir']}/consul/rm-health.sh" do
    source "consul/rm-health.sh.erb"
    owner node['hops']['rm']['user']
    group node['hops']['group']
    mode 0750
  end

  ha_ids = (0...node['hops']['rm']['private_ips'].size()).to_a()
  my_id = node['hops']['rm']['private_ips'].index(my_private_ip())

  consul_service "Registering ResourceManager with Consul" do
    service_definition "consul/rm-consul.hcl.erb"
    template_variables({
      :id => my_id
    })
    action :register
  end
end
