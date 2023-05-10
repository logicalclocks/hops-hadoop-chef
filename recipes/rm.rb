include_recipe "hops::default"

template "#{node['hops']['conf_dir']}/rm-jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode "400"
  action :create
end

template_ssl_server()
ndb_connectstring()

crypto_dir = x509_helper.get_crypto_dir(node['hops']['rm']['user'])
kagent_hopsify "Generate x.509" do
  user node['hops']['rm']['user']
  crypto_directory crypto_dir
  action :generate_x509
  not_if { node["kagent"]["enabled"] == "false" }
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

file "#{node['hops']['conf_dir']}/yarn_exclude_nodes.xml" do 
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode "700"
  content '<?xml version="1.0"?><hosts/>'
end

cookbook_file "#{node['hops']['conf_dir']}/resourcemanager.yaml" do 
  source "metrics/resourcemanager.yaml"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode 500
end

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

hopsworks_fqdn = nil
if service_discovery_enabled() && node['hops']['tls']['crl_enabled'].casecmp?("true")
  hopsworks_fqdn = consul_helper.get_service_fqdn("hopsworks.glassfish")
end
template systemd_script do
  source "#{service_name}.service.erb"
  owner "root"
  group "root"
  mode 0664
  variables({
            :deps => deps,
            :hopsworks_fqdn => hopsworks_fqdn
            })
  if node['services']['enabled'] == "true"
      notifies :enable, resources(:service => "#{service_name}")
  end
end

template "#{node['hops']['bin_dir']}/rm-waiter.sh" do
  source "rm-waiter.sh.erb"
  owner node['hops']['rm']['user']
  group node['hops']['group']
  mode 0750
  variables({
    :key => "#{crypto_dir}/#{x509_helper.get_private_key_pkcs8_name(node['hops']['rm']['user'])}",
    :certificate => "#{crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['hops']['rm']['user'])}"
  })
end

kagent_config "#{service_name}" do
  action :systemd_reload
end

bash 'wait-for-resourcemanager' do
  user node['hops']['rm']['user']
  group node['hops']['group']
  timeout 260
  code <<-EOH
    #{node['hops']['bin_dir']}/rm-waiter.sh
  EOH
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
  ha_ids = (0...node['hops']['rm']['private_ips'].size()).to_a()
  my_id = node['hops']['rm']['private_ips'].index(my_private_ip())

  # Register ResourceManager with Consul
  consul_crypto_dir = x509_helper.get_crypto_dir(node['consul']['user'])
  template "#{node['hops']['bin_dir']}/consul/rm-health.sh" do
    source "consul/rm-health.sh.erb"
    owner node['hops']['rm']['user']
    group node['hops']['group']
    mode 0750
    variables({
      :key => "#{consul_crypto_dir}/#{x509_helper.get_private_key_pkcs8_name(node['consul']['user'])}",
      :certificate => "#{consul_crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['consul']['user'])}",
      :id => my_id
      })
  end
  
  consul_service "Registering ResourceManager with Consul" do
    service_definition "consul/rm-consul.hcl.erb"
    template_variables({
      :id => my_id
    })
    action :register
  end
end
