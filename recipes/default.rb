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
zk_ip = private_recipe_ip('kzookeeper', 'default')
influxdb_ip = private_recipe_ip("hopsmonitor","default")

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

ndb_connectstring()

jdbc_url()


rpcSocketFactory = "org.apache.hadoop.net.StandardSocketFactory"
hopsworks_crl_uri = "RPC TLS NOT ENABLED"
if node['hops']['tls']['enabled'].eql? "true"
  rpcSocketFactory = node['hops']['hadoop']['rpc']['socket']['factory']
  if node['hops']['tls']['crl_input_uri'].empty?
    hopsworks_crl_uri = "Could not access hopsworks-chef"
    if node.attribute?("hopsworks")
      hopsworks_ip = private_recipe_ip("hopsworks", "default")
      hopsworks_port = "8181"
      if node['hopsworks'].attribute?(:secure_port)
        hopsworks_port = node['hopsworks']['secure_port']
      end
      hopsworks_crl_uri = "https://#{hopsworks_ip}:#{hopsworks_port}/intermediate.crl.pem"
    end
  else
    hopsworks_crl_uri = node['hops']['tls']['crl_input_uri']
  end
end

node.override['hopsworks']['port'] = hopsworks_port
node.override['hops']['hadoop']['rpc']['socket']['factory'] = rpcSocketFactory


firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"
baseNN = private_recipe_ip("hops", "nn") + ":#{nnPort}"
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


template "#{node['hops']['conf_dir']}/log4j.properties" do
  source "log4j.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "640"
  action :create
end

if node['ndb']['TransactionInactiveTimeout'].to_i < node['hops']['leader_check_interval_ms'].to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

#
# If there is a NN on this host, this will not override the NN's core-site.xml file which
# may have already been created. The NN will overwrite this core-site.xml file if it runs
# after the recipe that called this default['rb'] file.
#
template "#{node['hops']['conf_dir']}/core-site.xml" do
  source "core-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "740"
  variables({
     :firstNN => firstNN,
     :hopsworks => hopsworksNodes,
     :hopsworksUser => hopsworksUser,
     :livyUser => livyUser,
     :hiveUser => hiveUser,
     :jupyterUser => jupyterUser,
     :allNNs => allNNIps,
     :rpcSocketFactory => rpcSocketFactory,
     :hopsworks_crl_uri => hopsworks_crl_uri
  })
  action :create
end

template "#{node['hops']['conf_dir']}/hadoop-env.sh" do
  source "hadoop-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  action :create
end

template "#{node['hops']['conf_dir']}/jmxremote.access" do
  source "jmxremote.access.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "440"
  action :create
end

template "#{node['hops']['conf_dir']}/jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "400"
  action :create
end

template "#{node['hops']['conf_dir']}/yarn-jmxremote.password" do
  source "jmxremote.password.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "400"
  action :create
end


template "#{node['hops']['home']}/sbin/kill-process.sh" do
  source "kill-process.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "754"
  action :create
end

template "#{node['hops']['home']}/sbin/set-env.sh" do
  source "set-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "774"
  action :create
end


template "#{node['hops']['conf_dir']}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "750"
  cookbook "hops"
  variables({
              :firstNN => baseNN
            })
  action :create
end

template "#{node['hops']['conf_dir']}/erasure-coding-site.xml" do
  source "erasure-coding-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "740"
  action :create
end

# If CGroups are enabled, set the correct LCEResourceHandler
if node['hops']['yarn']['cgroups'].eql?("true") && node['hops']['gpu'].eql?("true")
  resource_handler = "org.apache.hadoop.yarn.server.nodemanager.util.CgroupsLCEResourcesHandlerGPU"
elsif node['hops']['yarn']['cgroups'].eql?("true") && node['hops']['gpu'].eql?("false")
  resource_handler = "org.apache.hadoop.yarn.server.nodemanager.util.CgroupsLCEResourcesHandler"
else
  resource_handler = "org.apache.hadoop.yarn.server.nodemanager.util.DefaultLCEResourcesHandler"
end

template "#{node['hops']['conf_dir']}/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "740"
  variables({
              :rm_private_ip => rm_dest_ip,
              :rm_public_ip => rm_public_ip,
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :zk_ip => zk_ip,
              :resource_handler => resource_handler
            })
  action :create
end

template "#{node['hops']['conf_dir']}/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner "root"
  group node['hops']['group']
  cookbook "hops"
  mode "740"
  variables({
              :hops_group => hops_group
            })
  action :create
end

template "#{node['hops']['conf_dir']}/ssl-server.xml" do
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

template "#{node['hops']['conf_dir']}/hadoop-metrics2.properties" do
  source "hadoop-metrics2.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "750"
  variables({
    :influxdb_ip => influxdb_ip
  })
  action :create
end

template "#{node['hops']['conf_dir']}/yarn-env.sh" do
  source "yarn-env.sh.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "750"
  action :create
end

# The ACL to keystore directory is needed during deployment
if node['hops']['tls']['enabled'].eql? "true"
  bash "update-acl-of-keystore" do
    user "root"
    code <<-EOH
         setfacl -Rm u:#{node['hops']['hdfs']['user']}:rx #{node['kagent']['certs_dir']}
         EOH
  end
end
