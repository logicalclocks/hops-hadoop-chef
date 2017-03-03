
case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.apache_hadoop.systemd = "false"
 end
end

for script in node.apache_hadoop.dn.scripts
  template "#{node.apache_hadoop.home}/sbin/#{script}" do
    source "#{script}.erb"
    owner node.apache_hadoop.hdfs.user
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0775
  end
end 

service_name="datanode"

if node.apache_hadoop.systemd == "true"

  case node.platform_family
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

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
if node.services.enabled == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, "service[#{service_name}]", :immediately
  end

  directory "/etc/systemd/system/#{service_name}.service.d" do
    owner "root"
    group "root"
    mode "755"
    action :create
    recursive true
  end

  template "/etc/systemd/system/#{service_name}.service.d/limits.conf" do
    source "limits.conf.erb"
    owner "root"
    mode 0774
    action :create
  end 

  apache_hadoop_start "reload_nn" do
    action :systemd_reload
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
    mode 0754
if node.services.enabled == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, resources(:service => "#{service_name}"), :immediately
  end

end

if node.kagent.enabled == "true" 
  kagent_config "#{service_name}" do
    service "HDFS"
    log_file "#{node.apache_hadoop.logs_dir}/hadoop-#{node.apache_hadoop.hdfs.user}-#{service_name}-#{node.hostname}.log"
    config_file "#{node.apache_hadoop.conf_dir}/hdfs-site.xml"
    web_port node.apache_hadoop.dn.http_port
  end
end
