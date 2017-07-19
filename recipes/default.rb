include_recipe "java"

case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.hops.systemd = "false"
 end
end

require 'resolv'

nnPort=node.hops.nn.port
hops_group=node.hops.group
my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")
rm_dest_ip = rm_private_ip
influxdb_ip = private_recipe_ip("hopsmonitor","default")

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

ndb_connectstring()

jdbc_url()

firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"
rpcNN = private_recipe_ip("hops", "nn") + ":#{nnPort}"

if node.hops.nn.private_ips.length > 1 
  allNNIps = node.hops.nn.private_ips.join(":#{nnPort},") + ":#{nnPort}"
else
  allNNIps = "#{node.hops.nn.private_ips[0]}" + ":#{nnPort}"
end

hopsworksNodes = ""
if node.hops.use_hopsworks.eql? "true"
  hopsworksNodes = node[:hopsworks][:default][:private_ips].join(",")
end


template "#{node.hops.home}/etc/hadoop/log4j.properties" do
  source "log4j.properties.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "664"
  action :create_if_missing
end

if node.ndb.TransactionInactiveTimeout.to_i < node.hops.leader_check_interval_ms.to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

template "#{node.hops.home}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  variables({
              :firstNN => firstNN,
              :hopsworks => hopsworksNodes,
              :allNNs => allNNIps
            })
end



template "#{node.hops.home}/etc/hadoop/mapred-site.xml" do 
  source "mapred-site.xml.erb"
  owner node.hops.mr.user
  group node.hops.group
  mode "755"
  variables({
              :rm_private_ip => rm_private_ip
            })
end

# file "#{node.hops.home}/etc/hadoop/hdfs-site.xml" do 
#   owner node.hops.hdfs.user
#   action :delete
# end


template "#{node.hops.home}/etc/hadoop/hadoop-env.sh" do
  source "hadoop-env.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
end


template "#{node.hops.home}/etc/hadoop/jmxremote.password" do
  source "jmxremote.password.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "600"
end

template "#{node.hops.home}/etc/hadoop/yarn-jmxremote.password" do
  source "jmxremote.password.erb"
  owner node.hops.yarn.user
  group node.hops.group
  mode "600"
end


template "#{node.hops.home}/sbin/kill-process.sh" do
  source "kill-process.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "754"
end

template "#{node.hops.home}/sbin/set-env.sh" do 
  source "set-env.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "774"
end


template "#{node.hops.conf_dir}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  cookbook "hops"
  variables({
              :firstNN => firstNN
            })
  action :create_if_missing  
end

# file "#{node.hops.home}/etc/hadoop/erasure-coding-site.xml" do 
#   owner node.hops.hdfs.user
#   action :delete
# end

template "#{node.hops.conf_dir}/erasure-coding-site.xml" do
  source "erasure-coding-site.xml.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  action :create_if_missing
end

container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node.hops.cgroups.eql? "true" 
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end

template "#{node.hops.home}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node.hops.yarn.user
  group node.hops.group
  cookbook "hops"
  mode "664"
  variables({
              :rm_private_ip => rm_dest_ip,
              :rm_public_ip => rm_public_ip,
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :container_executor => container_executor
            })
  action :create_if_missing
end

template "#{node.hops.home}/etc/hadoop/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner node.hops.yarn.user
  group node.hops.group
  cookbook "hops"
  mode "664"
  variables({
              :hops_group => hops_group
            })
  action :create_if_missing
end


template "#{node.hops.home}/etc/hadoop/hadoop-metrics2.properties" do
  source "hadoop-metrics2.properties.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode "755"
  variables({
              :influxdb_ip => influxdb_ip,
            })
  action :create_if_missing
end

bash 'update_owner_for_gpu' do
  user "root"
  code <<-EOH
    set -e
    chown root #{node.hops.dir}
    chown root #{node.hops.home}
    chmod 750 #{node.hops.home}
    chown root #{node.hops.conf_dir_parent}
    chmod 750 #{node.hops.conf_dir_parent}
    chown root #{node.hops.conf_dir}
    chmod 750 #{node.hops.conf_dir}
    chown root #{node.hops.conf_dir}/container-executor.cfg
    chmod 750 #{node.hops.conf_dir}/container-executor.cfg
    chown root #{node.hops.bin_dir}/container-executor
    chmod 6050 #{node.hops.bin_dir}/container-executor
  EOH
end

bash 'create_libhopsnvml_symlink' do
  user "root"
  code <<-EOH
    set -e
    ln -s #{node.hops.base_dir}/share/hadoop/yarn/lib/libhopsnvml-1.0.so #{node.hops.base_dir}/lib/native/libhopsnvml.so
    chown #{node.hops.hdfs.user}:#{node.hops.group} #{node.hops.base_dir}/lib/native/libhopsnvml.so
  EOH
end

template "#{node.hops.home}/etc/hadoop/yarn-env.sh" do
  source "yarn-env.sh.erb"
  owner node.hops.yarn.user
  group node.hops.group
  mode "664"
  action :create
end
