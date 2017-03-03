include_recipe "hops::wrap"

my_ip = my_private_ip()

nnPort = node.hops.nn.port

hopsworksNodes = ""
if node.hops.use_hopsworks.eql? "true"
  if node.hopsworks.nil? == false && node.hopsworks.default.nil? == false && node.hopsworks.default.private_ips.nil? == false
    hopsworksNodes = node.hopsworks.default.private_ips.join(",")
  end
end

if node.hops.nn.private_ips.length > 1 
  allNNs = node.hops.nn.private_ips.join(":#{nnPort},") + ":#{nnPort}"
else
  allNNs = "#{node.hops.nn.private_ips[0]}" + ":#{nnPort}"
end


file "#{node.hops.home}/etc/hadoop/core-site.xml" do 
  owner node.hops.hdfs.user
  action :delete
end

myNN = "#{my_ip}:#{nnPort}"
template "#{node.hops.home}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  variables({
              :firstNN => "hdfs://" + myNN,
              :hopsworks => hopsworksNodes,
              :allNNs => myNN
            })
end

cache = "true"
if node.hops.nn.cache.eql? "false"
   cache = "false"
end

partition_key = "true"
if node.hops.nn.partition_key.eql? "false"
   partition_key = "false"
end


file "#{node.hops.home}/etc/hadoop/hdfs-site.xml" do 
  owner node.hops.hdfs.user
  action :delete
end

template "#{node.hops.conf_dir}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  cookbook "hops"
  variables({
              :firstNN => myNN,
              :cache => cache,
              :partition_key => partition_key
            })
end

template "#{node.hops.home}/sbin/root-drop-and-recreate-hops-db.sh" do
  source "root-drop-and-recreate-hops-db.sh.erb"
  owner "root"
  mode "700"
end


template "#{node.hops.home}/sbin/drop-and-recreate-hops-db.sh" do
  source "drop-and-recreate-hops-db.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "771"
end


template "#{node.hops.home}/sbin/root-test-drop-full-recreate.sh" do
  source "root-test-drop-full-recreate.sh.erb"
  owner "root"
  mode "700"
end


include_recipe "hops::nn"


# TODO: This is a hack - sometimes the nn fails during install. If so, just restart it.

service_name="namenode"
if node.hops.systemd == "true"
  service "#{service_name}" do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end
else  #sysv
  service "#{service_name}" do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end
end

case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.apache_hadoop.systemd = "false"
 end
end

private_ip = my_private_ip()
public_ip = my_public_ip()

for script in node.apache_hadoop.nn.scripts
  template "#{node.apache_hadoop.home}/sbin/#{script}" do
    source "#{script}.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0775
  end
end 

Chef::Log.info "NameNode format option: #{node.apache_hadoop.nn.format_options}"

template "#{node.apache_hadoop.home}/sbin/format-nn.sh" do
  source "format-nn.sh.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode 0775
  variables({
            :format_opts => node.apache_hadoop.nn.format_options
        })
end



activeNN = true
ha_enabled = false
if node.apache_hadoop.ha_enabled.eql? "true" || node.apache_hadoop.ha_enabled == true # 
  ha_enabled = true
end

active_ip = private_recipe_ip("apache_hadoop","nn")
my_ip = my_private_ip()
# it is ok if all namenodes format the fs. Unless you add a new one later..
# if the nn has already been formatted, re-formatting it returns error
# TODO: test if the NameNode is running
if ::File.exist?("#{node.apache_hadoop.home}/.nn_formatted") === false || "#{node.apache_hadoop.reformat}" === "true"
  if activeNN == true
    sleep 10
    if "#{my_ip}" == "#{active_ip}"
       apache_hadoop_start "format-nn" do
         action :format_nn
         ha_enabled ha_enabled
       end
    end
  else
    # wait for the active nn to come up
    # TODO - copy fsimage over from the active nn
    sleep 100
  end
else 
  Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node.apache_hadoop.nn.name_dir}/current) and set node.apache_hadoop.reformat to true"
end

if ha_enabled == true

  template "#{node.apache_hadoop.home}/sbin/start-zkfc.sh" do
    source "start-zkfc.sh.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0754
  end

  template "#{node.apache_hadoop.home}/sbin/start-standby-nn.sh" do
    source "start-standby-nn.sh.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0754
  end


  apache_hadoop_start "zookeeper-format" do
    action :zkfc
    ha_enabled ha_enabled
  end

  if activeNN == false
    apache_hadoop_start "standby-nn" do
      action :standby
      ha_enabled ha_enabled
    end
  end
end

service_name="namenode"

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

else  #sysv

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
    config_file "#{node.apache_hadoop.conf_dir}/hdfs-site.xml"
    log_file "#{node.apache_hadoop.logs_dir}/hadoop-#{node.apache_hadoop.hdfs.user}-#{service_name}-#{node.hostname}.log"
    web_port node.apache_hadoop.nn.http_port
  end
end

tmp_dirs   = [ "/tmp", node.apache_hadoop.hdfs.user_home, node.apache_hadoop.hdfs.user_home + "/" + node.apache_hadoop.hdfs.user ]

for d in tmp_dirs
  apache_hadoop_hdfs_directory d do
    action :create_as_superuser
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode "1775"
    not_if ". #{node.apache_hadoop.base_dir}/sbin/set-env.sh && #{node.apache_hadoop.base_dir}/bin/hdfs dfs -test -d #{d}"
  end
end
