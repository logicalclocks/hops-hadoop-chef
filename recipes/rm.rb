include_recipe "hops::default"

my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")
rm_dest_ip = rm_private_ip

ndb_connectstring()

template "#{node.hops.home}/etc/hadoop/RM_EventAPIConfig.ini" do 
  source "RM_EventAPIConfig.ini.erb"
  owner node.hops.yarn.user
  group node.hops.group
  mode "755"
  variables({
              :ndb_connectstring => node.ndb.connectstring
            })
end


yarn_service="rm"
service_name="resourcemanager"
my_ip = my_private_ip()
my_public_ip = my_public_ip()
container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node.hops.cgroups.eql? "true" 
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end

file "#{node.hops.home}/etc/hadoop/yarn-site.xml" do 
  owner node.hops.yarn.user
  action :delete
end

template "#{node.hops.home}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node.hops.yarn.user
  group node.hops.group
  mode "660"
  variables({
              :rm_private_ip => my_ip,
              :rm_public_ip => my_public_ip,
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :container_executor => container_executor
            })
  action :create_if_missing
end


for script in node.hops.yarn.scripts
  template "#{node.hops.home}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node.hops.yarn.user
     group node.hops.group
    mode 0775
  end
end 

template "#{node.hops.home}/sbin/yarn.sh" do
  source "yarn.sh.erb"
  owner node.hops.yarn.user
  group node.hops.group
  mode 0775
end


if node.hops.systemd == "true"

  case node.platform_family
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


  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
if node.services.enabled == "true"
    notifies :enable, resources(:service => "#{service_name}")
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
  end 

  hops_start "reload_nn" do
    action :systemd_reload
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
if node.services.enabled == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, resources(:service => service_name)
  end



end

if node.kagent.enabled == "true" 
  kagent_config "resourcemanager" do
    service "YARN"
    log_file "#{node.hops.logs_dir}/yarn-#{node.hops.yarn.user}-#{service_name}-#{node.hostname}.log"
    config_file "#{node.hops.conf_dir}/yarn-site.xml"
    web_port node.hops["#{yarn_service}"][:http_port]
  end
end

tmp_dirs   = [node.hops.hdfs.user_home + "/" + node.hops.yarn.user]
for d in tmp_dirs
  hops_hdfs_directory d do
    action :create_as_superuser
    owner node.hops.yarn.user
    group node.hops.group
    mode "1775"
  end
end

tmp_dirs   = [node.hops.yarn.nodemanager.remote_app_log_dir]
for d in tmp_dirs
  hops_hdfs_directory d do
    action :create_as_superuser
    owner node.hops.yarn.user
    group node.hops.group
    mode "1773"
  end
end
