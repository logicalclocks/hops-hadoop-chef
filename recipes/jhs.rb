include_recipe "hops::default"


yarn_service="jhs"
service_name="historyserver"

for script in node['hops']['yarn']['scripts']
  template "#{node['hops']['home']}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node['hops']['yarn']['user']
    group node['hops']['group']
    mode 0775
  end
end 


tmp_dirs   = ["/mr-history", node['hops']['jhs']['inter_dir'], node['hops']['jhs']['done_dir']]

 for d in tmp_dirs
   Chef::Log.info "Creating hdfs directory: #{d}"
   hops_hdfs_directory d do
    action :create_as_superuser
    owner node['hops']['mr']['user']
    group node['hops']['group']
    mode "1775"
   end
 end

node.normal['mr']['dirs'] = [node['hops']['mr']['staging_dir'], node['hops']['mr']['tmp_dir'], node['hops']['hdfs']['user_home'] + "/" + node['hops']['mr']['user']]
 for d in node['mr']['dirs']
   Chef::Log.info "Creating hdfs directory: #{d}"
   hops_hdfs_directory d do
    action :create_as_superuser
    owner node['hops']['mr']['user']
    group node['hops']['group']
    mode "0775"
   end
 end

if node['hops']['systemd'] == "true"

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  case node['platform_family']
  when "debian"
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
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
if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
end
    notifies :restart, resources(:service => service_name)
  end

  kagent_config "#{service_name}" do
    action :systemd_reload
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
    mode 0774
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
    notifies :enable, resources(:service => service_name)
end
    notifies :restart, resources(:service => service_name), :immediately
  end

end

if node['kagent']['enabled'] == "true" 
  kagent_config service_name do
    service "MAP_REDUCE"
    log_file "#{node['hops']['logs_dir']}/mapred-#{node['hops']['mr']['user']}-#{service_name}-#{node['hostname']}.log"
    config_file "#{node['hops']['conf_dir']}/mapred-site.xml"
    web_port node['hops']["#{yarn_service}"]['http_port']
  end
end

