include_recipe "hops::default"

template_ssl_server()

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

deps = "consul.service"
if exists_local("hops", "nn") 
  deps = "#{deps} namenode.service"
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

  
  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
    variables({
              :deps => deps
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
