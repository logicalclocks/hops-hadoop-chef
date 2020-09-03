include_recipe "hops::default"

template_ssl_server()

# DataNode and NameNode run as the same user
# Generate certificate only once
unless exists_local("hops", "nn")
  crypto_dir = x509_helper.get_crypto_dir(node['hops']['hdfs']['user'])
  kagent_hopsify "Generate x.509" do
    user node['hops']['hdfs']['user']
    crypto_directory crypto_dir
    action :generate_x509
    not_if { node["kagent"]["enabled"] == "false" }
  end
end

for script in node['hops']['dn']['scripts']
  template "#{node['hops']['sbin_dir']}/#{script}" do
    source "#{script}.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['secure_group']
    mode 0750
  end
end 

cookbook_file "#{node['hops']['conf_dir']}/datanode.yaml" do 
  source "metrics/datanode.yaml"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode 500
end

deps = ""
if service_discovery_enabled()
  deps += "consul.service "
end
if exists_local("hops", "nn") 
  deps += "namenode.service "
end  

service_name="datanode"

if node['hops']['systemd'] == "true"

  case node['platform_family']
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  else
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  service "#{service_name}" do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  file systemd_script do
    action :delete
    ignore_failure true
  end

  rpc_namenode_fqdn = my_private_ip()
  if service_discovery_enabled()
    rpc_namenode_fqdn = consul_helper.get_service_fqdn("rpc.namenode")
  end
  
  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
    variables({
                :deps => deps,
                :nn_rpc_endpoint => rpc_namenode_fqdn
              })
if node['services']['enabled'] == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, "service[#{service_name}]"
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
    notifies :restart, "service[#{service_name}]"    
  end 

  kagent_config "#{service_name}" do
    action :systemd_reload
    not_if "systemctl status datanode"    
  end
  
  
else #sysv

  service "#{service_name}" do
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
    notifies :restart, resources(:service => "#{service_name}"), :immediately
  end

end

if node['kagent']['enabled'] == "true" 
  kagent_config service_name do
    service "HDFS"
    log_file "#{node['hops']['logs_dir']}/hadoop-#{node['hops']['hdfs']['user']}-#{service_name}-#{node['hostname']}.log"
    config_file "#{node['hops']['conf_dir']}/hdfs-site.xml"
  end
end

if service_discovery_enabled()
  # Register DataNode with Consul
  template "#{node['hops']['bin_dir']}/consul/dn-health.sh" do
    source "consul/dn-health.sh.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode 0750
  end

  consul_service "Registering DataNode with Consul" do
    service_definition "consul/dn-consul.hcl.erb"
    action :register
  end
end
