include_recipe "java"

case node['platform']
when "ubuntu"
 if node['platform_version'].to_f <= 14.04
   node.override['hops']['systemd'] = "false"
 end
end

require 'resolv'


group node['hops']['group'] do
  action :modify
  members ["#{node['conda']['user']}"]
  append true
end


nnPort=node['hops']['nn']['port']
hops_group=node['hops']['group']
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


rpcSocketFactory = "org.apache.hadoop.net.StandardSocketFactory"
hopsworks_endpoint = "RPC TLS NOT ENABLED"
if node['hops']['rpc']['ssl'].eql? "true"
  rpcSocketFactory = node['hops']['hadoop']['rpc']['socket']['factory']
  hopsworks_endpoint = "Could not access hopsworks-chef"
  if node.attribute?("hopsworks")
    hopsworks_ip = private_recipe_ip("hopsworks", "default")
    hopsworks_port = "8080"
    if node['hopsworks'].attribute?(:port)
      hopsworks_port = node['hopsworks']['port']
    end
    hopsworks_endpoint = "http://#{hopsworks_ip}:#{hopsworks_port}"
  end
end

node.override['hopsworks']['port'] = hopsworks_port
node.override['hops']['hadoop']['rpc']['socket']['factory'] = rpcSocketFactory


firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"
rpcNN = private_recipe_ip("hops", "nn") + ":#{nnPort}"

if node['hops']['nn']['private_ips'].length > 1
  allNNIps = node['hops']['nn']['private_ips'].join(":#{nnPort},") + ":#{nnPort}"
else
  allNNIps = "#{node['hops']['nn']['private_ips'][0]}" + ":#{nnPort}"
end

#
# Constraints for Attributes - enforce them!
#


# If the user specified "gpu" to be true in a cluster definition, then accept that.
# Else, if cuda/accept_nvidia_download_terms is set to true, then make 'gpu' true.
if node['hops']['gpu'].eql?("false")
  if node.attribute?("cuda") && node['cuda'].attribute?("accept_nvidia_download_terms") && node['cuda']['accept_nvidia_download_terms'].eql?("true")
     node.override['hops']['gpu'] = "true"
  end
end

if node['hops']['yarn']['gpus'].eql?("*")
    num_gpus = ::File.open('/tmp/num_gpus', 'rb') { |f| f.read }
    node.override['hops']['yarn']['gpus'] = num_gpus.delete!("\n")
end

Chef::Log.info "Number of gpus found was: #{node['hops']['yarn']['gpus']}"

if node['hops']['gpu'].eql? "true"
   node.override['hops']['cgroups'] = "true"
   node.override['hops']['capacity']['resource_calculator_class'] = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculatorGPU"
end

#
# End Constraints
#

hopsworksNodes = ""

hopsworksUser = "glassfish"
if node.attribute?("hopsworks")
  hopsworksNodes = node['hopsworks']['default']['private_ips'].join(",")
  if node['hopsworks'].attribute?("user")
    hopsworksUser = node['hopsworks']['user']
  end
end
node.override['hopsworks']['user'] = hopsworksUser

jupyterUser = "jupyter"
if node.attribute?('jupyter')
  if node['jupyter'].attribute?('user')
    jupyterUser = node['jupyter']['user']
  end
end
node.override['jupyter']['user'] = jupyterUser

livyUser = "livy"
if node.attribute?("livy")
  if node['livy'].attribute?("user")
    livyUser = node['livy']['user']
  end
end
node.override['livy']['user'] = livyUser

hiveUser = "hive"
if node.attribute?("hive2")
  if node['hive2'].attribute?("user")
    hiveUser = node['hive2']['user']
  end
end
node.override['hive2']['user'] = hiveUser


template "#{node['hops']['home']}/etc/hadoop/log4j.properties" do
  source "log4j.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "664"
  action :create_if_missing
end

if node['ndb']['TransactionInactiveTimeout'].to_i < node['hops']['leader_check_interval_ms'].to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

#
# If there is a NN on this host, this will not override the NN's core-site.xml file which
# may have already been created. The NN will overwrite this core-site.xml file if it runs
# after the recipe that called this default['rb'] file.
#
template "#{node['hops']['home']}/etc/hadoop/core-site.xml" do
  source "core-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  variables({
              :firstNN => firstNN,
              :hopsworks => hopsworksNodes,
              :hopsworksUser => hopsworksUser,
              :livyUser => livyUser,
              :hiveUser => hiveUser,
              :jupyterUser => jupyterUser,
              :allNNs => allNNIps,
              :rpcSocketFactory => rpcSocketFactory,
              :hopsworks_endpoint => hopsworks_endpoint
            })
  action :create_if_missing
end

# file "#{node['hops']['home']}/etc/hadoop/hdfs-site.xml" do
#   owner node['hops']['hdfs']['user']
#   action :delete
# end


template "#{node['hops']['home']}/etc/hadoop/hadoop-env.sh" do
  source "hadoop-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
end


template "#{node['hops']['home']}/etc/hadoop/jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "400"
end

template "#{node['hops']['home']}/etc/hadoop/yarn-jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "400"
end


template "#{node['hops']['home']}/sbin/kill-process.sh" do
  source "kill-process.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "754"
end

template "#{node['hops']['home']}/sbin/set-env.sh" do
  source "set-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "774"
end


template "#{node['hops']['conf_dir']}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  cookbook "hops"
  variables({
              :firstNN => firstNN
            })
  action :create_if_missing
end

# file "#{node['hops']['home']}/etc/hadoop/erasure-coding-site.xml" do
#   owner node['hops']['hdfs']['user']
#   action :delete
# end

template "#{node['hops']['conf_dir']}/erasure-coding-site.xml" do
  source "erasure-coding-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  action :create_if_missing
end

container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node['hops']['cgroups'].eql? "true"
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end

template "#{node['hops']['home']}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
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

template "#{node['hops']['home']}/etc/hadoop/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "664"
  variables({
              :hops_group => hops_group
            })
  action :create_if_missing
end

template "#{node['hops']['home']}/etc/hadoop/ssl-server.xml" do
  source "ssl-server.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['kagent']['certs_group']
  mode "750"
  variables({
              :kstore => "#{node['kagent']['keystore_dir']}/#{node['hostname']}__kstore.jks",
              :tstore => "#{node['kagent']['keystore_dir']}/#{node['hostname']}__tstore.jks"
            })
  action :create
end

template "#{node['hops']['home']}/etc/hadoop/hadoop-metrics2.properties" do
  source "hadoop-metrics2.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  variables({
              :influxdb_ip => influxdb_ip,
            })
  action :create_if_missing
end

link "#{node['hops']['base_dir']}/lib/native/libhopsnvml-#{node['hops']['libhopsnvml_version']}.so" do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  to "#{node['hops']['base_dir']}/share/hadoop/yarn/lib/libhopsnvml-#{node['hops']['libhopsnvml_version']}.so"
end

if node['hops']['gpu'].eql? "true"
  bash 'update_owner_for_gpu' do
    user "root"
    code <<-EOH
    set -e
    chown root:#{node['hops']['group']} #{node['hops']['dir']}
    chown root:#{node['hops']['group']} #{node['hops']['home']}
    chmod 750 #{node['hops']['home']}
    chown root #{node['hops']['conf_dir_parent']}
    chmod 750 #{node['hops']['conf_dir_parent']}
    chown root:#{node['hops']['group']} #{node['hops']['conf_dir']}
    chmod 750 #{node['hops']['conf_dir']}
    chown root #{node['hops']['conf_dir']}/container-executor.cfg
    chmod 750 #{node['hops']['conf_dir']}/container-executor.cfg
    chown root #{node['hops']['bin_dir']}/container-executor
    chmod 6050 #{node['hops']['bin_dir']}/container-executor
  EOH
  end
end

template "#{node['hops']['home']}/etc/hadoop/yarn-env.sh" do
  source "yarn-env.sh.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "664"
  action :create
end

# The ACL to keystore directory is needed during deployment
if node['hops']['rpc']['ssl'].eql? "true"
  bash "update-acl-of-keystore" do
    user "root"
    code <<-EOH
         setfacl -Rm u:#{node['hops']['hdfs']['user']}:rx #{node['kagent']['certs_dir']}
         EOH
  end
end
