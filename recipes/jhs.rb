include_recipe "apache_hadoop::yarn"


yarn_service="jhs"
service_name="historyserver"

for script in node.apache_hadoop.yarn.scripts
  template "#{node.apache_hadoop.home}/sbin/#{script}-#{yarn_service}.sh" do
    source "#{script}-#{yarn_service}.sh.erb"
    owner node.apache_hadoop.yarn.user
    group node.apache_hadoop.group
    mode 0775
  end
end 


tmp_dirs   = ["/mr-history", node.apache_hadoop.jhs.inter_dir, node.apache_hadoop.jhs.done_dir]

 for d in tmp_dirs
   Chef::Log.info "Creating hdfs directory: #{d}"
   apache_hadoop_hdfs_directory d do
    action :create_as_superuser
    owner node.apache_hadoop.mr.user
    group node.apache_hadoop.group
    mode "1775"
    not_if ". #{node.apache_hadoop.home}/sbin/set-env.sh && #{node.apache_hadoop.home}/bin/hdfs dfs -test -d #{d}"
   end
 end

node.normal.mr.dirs = [node.apache_hadoop.mr.staging_dir, node.apache_hadoop.mr.tmp_dir, node.apache_hadoop.hdfs.user_home + "/" + node.apache_hadoop.mr.user]
 for d in node.mr.dirs
   Chef::Log.info "Creating hdfs directory: #{d}"
   apache_hadoop_hdfs_directory d do
    action :create_as_superuser
    owner node.apache_hadoop.mr.user
    group node.apache_hadoop.group
    mode "0775"
    not_if ". #{node.apache_hadoop.home}/sbin/set-env.sh && #{node.apache_hadoop.home}/bin/hdfs dfs -test -d #{d}"
   end
 end

if node.apache_hadoop.systemd == "true"

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  case node.platform_family
  when "debian"
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
if node.services.enabled == "true"
    notifies :enable, resources(:service => service_name)
end
    notifies :restart, resources(:service => service_name), :immediately
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

  service service_name do
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
    notifies :enable, resources(:service => service_name)
end
    notifies :restart, resources(:service => service_name), :immediately
  end

end

if node.kagent.enabled == "true" 
  kagent_config service_name do
    service "MAP_REDUCE"
    log_file "#{node.apache_hadoop.logs_dir}/mapred-#{node.apache_hadoop.mr.user}-#{service_name}-#{node.hostname}.log"
    config_file "#{node.apache_hadoop.conf_dir}/mapred-site.xml"
    web_port node.apache_hadoop["#{yarn_service}"][:http_port]
  end
end

