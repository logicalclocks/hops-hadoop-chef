include_recipe "hops::default"

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


include_recipe "hops::default" 


# TODO: This is a hack - sometimes the nn fails during install. If so, just restart it.

# service_name="namenode"
# if node.hops.systemd == "true"
#   service "#{service_name}" do
#     provider Chef::Provider::Service::Systemd
#     supports :restart => true, :stop => true, :start => true, :status => true
#     action :restart
#   end
# else  #sysv
#   service "#{service_name}" do
#     provider Chef::Provider::Service::Init::Debian
#     supports :restart => true, :stop => true, :start => true, :status => true
#     action :restart
#   end
# end


for script in node.hops.nn.scripts
  template "#{node.hops.home}/sbin/#{script}" do
    source "#{script}.erb"
    owner node.hops.hdfs.user
    group node.hops.group
    mode 0775
  end
end 

Chef::Log.info "NameNode format option: #{node.hops.nn.format_options}"

template "#{node.hops.home}/sbin/format-nn.sh" do
  source "format-nn.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode 0775
  variables({
            :format_opts => node.hops.nn.format_options
        })
end



# it is ok if all namenodes format the fs. Unless you add a new one later..
# if the nn has already been formatted, re-formatting it returns error
# TODO: test if the NameNode is running
if ::File.exist?("#{node.hops.home}/.nn_formatted") === false || "#{node.hops.reformat}" === "true"
   hops_start "format-nn" do
     action :format_nn
   end
else 
  Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node.hops.nn.name_dir}/current) and set node.hops.reformat to true"
end

service_name="namenode"

if node.hops.systemd == "true"

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
    mode 0664
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
  end

  template "/etc/systemd/system/#{service_name}.service.d/limits.conf" do
    source "limits.conf.erb"
    owner "root"
    mode 0664
    action :create
    notifies :restart, "service[#{service_name}]"    
  end 

  hops_start "reload_nn" do
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
    mode 0755
if node.services.enabled == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, resources(:service => "#{service_name}"), :immediately
  end 
end



if node.kagent.enabled == "true" 
  kagent_config "#{service_name}" do
    service "HDFS"
    config_file "#{node.hops.conf_dir}/hdfs-site.xml"
    log_file "#{node.hops.logs_dir}/hadoop-#{node.hops.hdfs.user}-#{service_name}-#{node.hostname}.log"
    web_port node.hops.nn.http_port
  end
end

tmp_dirs   = [ "/tmp", node.hops.hdfs.user_home, node.hops.hdfs.user_home + "/" + node.hops.hdfs.user ]

for d in tmp_dirs
  hops_hdfs_directory d do
    action :create_as_superuser
    owner node.hops.hdfs.user
    group node.hops.group
    mode "1775"
  end
end


hopsworks_user=node["hops"]["hdfs"]["user"]

if node.attribute?('hopsworks') == true
  if node['hopsworks'].attribute?('user') == true
     hopsworks_user = node['hopsworks']['user']
  end
end

hopsUtil=File.basename(node["hops"]["hops_util"]["url"])
 
remote_file "#{Chef::Config["file_cache_path"]}/#{hopsUtil}" do
  source node["hops"]["hops_util"]["url"]
  owner hopsworks_user
  group node["hops"]["group"]
  mode "1775"
  action :create
end

hops_hdfs_directory "#{Chef::Config["file_cache_path"]}/hops-util-0.1.jar" do
  action :put_as_superuser
  owner hopsworks_user
  group node["hops"]["group"]
  mode "1755"
  dest "/user/#{hopsworks_user}/hops-util-0.1.jar"
end

hopsKafkaJar=File.basename(node["hops"]["hops_spark_kafka_example"]["url"])
 
remote_file "#{Chef::Config["file_cache_path"]}/#{hopsKafkaJar}" do
  source node["hops"]["hops_spark_kafka_example"]["url"]
  owner hopsworks_user
  group hopsworks_user
  mode "1775"
  action :create
end

hops_hdfs_directory "#{Chef::Config["file_cache_path"]}/#{hopsKafkaJar}" do
  action :put_as_superuser
  owner hopsworks_user
  group node["hops"]["group"]
  mode "1755"
  dest "/user/#{hopsworks_user}/#{hopsKafkaJar}"
end

