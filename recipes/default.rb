include_recipe "java"
include_recipe "hops::_config"

Chef::Recipe.send(:include, Hops::Helpers)

if not node["hopsworks"]["default"].attribute?("public_ips")
  Chef::Log.warn("Hopsworks cookbook was not loaded, disabling Hops TLS and JWT support!")
  node.override['hops']['tls']['enabled'] = "false"
  node.override['hops']['rmappsecurity']['jwt']['enabled'] = "false"
end

case node['platform']
when "ubuntu"
 if node['platform_version'].to_f <= 14.04
   node.override['hops']['systemd'] = "false"
 end
end

require 'resolv'

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
    if node['hops']['tls']['enabled'].eql? "true"
      hopsworks_crl_uri = "#{hopsworks_host()}/intermediate.crl.pem"
    end
  else
    hopsworks_crl_uri = node['hops']['tls']['crl_input_uri']
  end
end

node.override['hops']['hadoop']['rpc']['socket']['factory'] = rpcSocketFactory

firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"
if node['hops']['nn']['private_ips'].include?(my_ip)
  # This is a namenode machine, the rpc-address in hdfs-site.xml is used as "bind to" address
  nn_rpc_address = "#{my_ip}:#{nnPort}"
  nn_http_address = "#{my_ip}:#{node['hops']['nn']['http_port']}"
else
  # This is a non namenode machine, a random namenode works
  nn_rpc_address = private_recipe_ip("hops", "nn") + ":#{nnPort}"
end

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
  num_gpus = 0
  if node['hops']['yarn']['gpus'].eql?("*") && node['hops']['yarn']['gpu_impl_class'].eql?("io.hops.management.nvidia.NvidiaManagementLibrary")
    ruby_block 'discover_gpus' do
      block do
        Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
        command = "nvidia-smi -L | wc -l"
        num_gpus = shell_out(command).stdout.gsub(/\n/, '')
      end
    end
  end
  if node['hops']['yarn']['gpus'].eql?("*") && node['hops']['yarn']['gpu_impl_class'].eql?("io.hops.management.amd.AMDManagementLibrary")
    ruby_block 'discover_gpus' do
      block do
        Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
        num_gpus = Dir["/sys/module/amdgpu/drivers/pci:amdgpu/*/drm/card*"].length
      end
    end
  end

else
  num_gpus = node['hops']['yarn']['gpus']
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

sqoopUser = "sqoop"
if node.attribute?('sqoop')
  if node['sqoop'].attribute?('user')
    sqoopUser = node['sqoop']['user']
  end
end
node.override['sqoop']['user'] = sqoopUser


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
     :sqoopUser => sqoopUser,     
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
    :nn_rpc_address => nn_rpc_address,
    :nn_http_address => nn_http_address
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

var_hopsworks_host = hopsworks_host()
template "#{node['hops']['conf_dir']}/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "740"
  variables( lazy {
    h = {}
    h[:rm_private_ip] = rm_dest_ip
    h[:rm_public_ip] = rm_public_ip
    h[:my_public_ip] = my_public_ip
    h[:my_private_ip] = my_ip
    h[:zk_ip] = zk_ip
    h[:resource_handler] = resource_handler
    h[:hopsworks_host] = var_hopsworks_host
    h[:num_gpus] = num_gpus
    h
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

# Remove previous cron entry
bash "remove-hadoop-log-copy-cron" do
  case node['platform_family']
  when "rhel"
    crontab = "/var/spool/cron/#{node['hops']['hdfs']['user']}"
  else
    crontab = "/var/spool/cron/crontabs/#{node['hops']['hdfs']['user']}"
  end
  user 'root'
  group 'root'
  code <<-EOH
       sed -i '/copy_hadoop_logs/d' #{crontab}
       sed -i '/delete_hadoop_logs/d' #{crontab}
       sed -i '/hadoop_logs_mgm.py/d' #{crontab}
  EOH
  only_if do File.exist?("#{crontab}") end
end

# hops-system anaconda environment is created at conda::default
cron "copy_hadoop_logs" do
  command "HADOOP_HOME=#{node['hops']['base_dir']} CLASSPATH=$(#{node['hops']['bin_dir']}/hadoop classpath --glob) #{node['conda']['base_dir']}/envs/hops-system/bin/python #{node['hops']['bin_dir']}/hadoop_logs_mgm.py -c #{node['hops']['conf_dir']}/hadoop_logs_mgm.ini backup"
  user node['hops']['hdfs']['user']
  minute '0'
  hour '2'
  day '*'
  month '*'
  only_if do File.exist?("#{node['hops']['bin_dir']}/hadoop_logs_mgm.py") end
end

# Schedule deletion of old logs to run only on a single machine
if my_ip.eql? node['hops']['nn']['private_ips'][0]
  cron "delete_hadoop_logs" do
    command "HADOOP_HOME=#{node['hops']['base_dir']} CLASSPATH=$(#{node['hops']['bin_dir']}/hadoop classpath --glob) #{node['conda']['base_dir']}/envs/hops-system/bin/python #{node['hops']['bin_dir']}/hadoop_logs_mgm.py -c #{node['hops']['conf_dir']}/hadoop_logs_mgm.ini delete"
    user node['hops']['hdfs']['user']
    minute '0'
    hour '4'
    day '*'
    month '*'
    only_if do File.exist?("#{node['hops']['bin_dir']}/hadoop_logs_mgm.py") end
  end
end

if node['hops']['topology'].eql? "true"
  template "#{node['hops']['conf_dir']}/get-topology.sh" do
    source "get-topology.sh.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "755"
    action :create
  end

  template "#{node['hops']['conf_dir']}/topology" do
    source "topology.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "755"
    action :create
  end
end
