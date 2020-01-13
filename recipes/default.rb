include_recipe "java"
include_recipe "hops::_config"

Chef::Recipe.send(:include, Hops::Helpers)

if not node["hopsworks"]["default"].attribute?("public_ips")
  Chef::Log.warn("Hopsworks cookbook was not loaded, disabling Hops TLS and JWT support!")
  node.override['hops']['tls']['enabled'] = "false"
  node.override['hops']['rmappsecurity']['jwt']['enabled'] = "false"
end

require 'resolv'

nnPort=node['hops']['nn']['port']
hops_group=node['hops']['group']
my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
zk_ip = private_recipe_ip('kzookeeper', 'default')

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

ndb_connectstring()

rpcSocketFactory = "org.apache.hadoop.net.StandardSocketFactory"
hopsworks_crl_uri = "RPC TLS NOT ENABLED"
if node['hops']['tls']['enabled'].eql? "true"
  rpcSocketFactory = node['hops']['hadoop']['rpc']['socket']['factory']
  hopsworks_crl_uri = "#{hopsworks_host()}#{node['hops']['tls']['crl_fetch_path']}"
end

node.override['hops']['hadoop']['rpc']['socket']['factory'] = rpcSocketFactory

if node['hops']['nn']['private_ips'].length > 1
  allNNIps = node['hops']['nn']['private_ips'].join(":#{nnPort},") + ":#{nnPort}"
else
  allNNIps = "#{node['hops']['nn']['private_ips'][0]}" + ":#{nnPort}"
end

# This is a namenode machine, the rpc-address in hdfs-site.xml is used as "bind to" address
if node['hops']['nn']['private_ips'].include?(my_ip)
  nn_rpc_address = "#{my_ip}:#{nnPort}"
  nn_http_address = "#{my_ip}:#{node['hops']['nn']['http_port']}"
  nn_https_address = "#{my_ip}:#{node['hops']['dfs']['https']['port']}"
else
  # This is a non namenode machine, a random namenode works
  nn_rpc_address = private_recipe_ip("hops", "nn") + ":#{nnPort}"
  nn_http_address = private_recipe_ip("hops", "nn") + ":#{node['hops']['nn']['http_port']}"
  nn_https_address = private_recipe_ip("hops", "nn") + ":#{node['hops']['nn']['https_port']}"
end

defaultFS = "hdfs://#{nn_rpc_address}"

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

hopsworksUser = "glassfish"
if node.attribute?("hopsworks")
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

servingUser = "serving"
if node.attribute?('serving')
  if node['serving'].attribute?('user')
    servingUser = node['serving']['user']
  end
end
node.override['serving']['user'] = servingUser

flinkUser = "flink"
if node.attribute?('flink')
  if node['flink'].attribute?('user')
    flinkUser = node['flink']['user']
  end
end
node.override['flink']['user'] = flinkUser

template "#{node['hops']['conf_dir']}/log4j.properties" do
  source "log4j.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "644"
  action :create
end

if node['ndb']['TransactionInactiveTimeout'].to_i < node['hops']['leader_check_interval_ms'].to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

var_hopsworks_host = hopsworks_host()

template "#{node['hops']['conf_dir']}/core-site.xml" do
  source "core-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "744"
  variables({
     :defaultFS => defaultFS,
     :hopsworks => var_hopsworks_host,
     :hopsworksUser => hopsworksUser,
     :livyUser => livyUser,
     :hiveUser => hiveUser,
     :jupyterUser => jupyterUser,
     :sqoopUser => sqoopUser,
     :servingUser => servingUser,
     :flinkUser => flinkUser,
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


template "#{node['hops']['sbin_dir']}/kill-process.sh" do
  source "kill-process.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['secure_group']
  mode "750"
  action :create
end

template "#{node['hops']['sbin_dir']}/set-env.sh" do
  source "set-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['secure_group']
  mode "750"
  action :create
end

location_domain_id = node['hops']['nn']['private_ips_domainIds'].has_key?(my_ip) ? node['hops']['nn']['private_ips_domainIds'][my_ip] : 0
template "#{node['hops']['conf_dir']}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "754"
  cookbook "hops"
  variables({
    :nn_rpc_address => nn_rpc_address,
    :location_domain_id => location_domain_id,
    :nn_http_address => nn_http_address,
    :nn_https_address => nn_https_address
  })
  action :create
end

template "#{node['hops']['conf_dir']}/erasure-coding-site.xml" do
  source "erasure-coding-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "744"
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

if node['hops']['rm']['private_ips'].include?(my_ip)
  # This is a resource manager machine
  rm_private_ip = my_ip;
end

if node['hops']['yarn']['detect-hardware-capabilities'].casecmp?("true")
  node.override['hops']['yarn']['vcores'] = "-1"
  node.override['hops']['yarn']['memory_mbs'] = "-1"
end

template "#{node['hops']['conf_dir']}/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "744"
  variables( lazy {
    h = {}
    h[:rm_private_ip] = rm_private_ip
    h[:my_private_ip] = my_ip
    h[:zk_ip] = zk_ip
    h[:resource_handler] = resource_handler
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
  command "HADOOP_HOME=#{node['hops']['base_dir']} PATH=#{node['hops']['bin_dir']}:$PATH CLASSPATH=$(#{node['hops']['bin_dir']}/hadoop classpath --glob) #{node['conda']['base_dir']}/envs/hops-system/bin/python #{node['hops']['bin_dir']}/hadoop_logs_mgm.py -c #{node['hops']['conf_dir']}/hadoop_logs_mgm.ini backup"
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
    command "HADOOP_HOME=#{node['hops']['base_dir']} PATH=#{node['hops']['bin_dir']}:$PATH CLASSPATH=$(#{node['hops']['bin_dir']}/hadoop classpath --glob) #{node['conda']['base_dir']}/envs/hops-system/bin/python #{node['hops']['bin_dir']}/hadoop_logs_mgm.py -c #{node['hops']['conf_dir']}/hadoop_logs_mgm.ini delete"
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

# This is templated here so that the hops::ndb recipe will find it when invoking the format 
cookbook_file "#{node['hops']['conf_dir']}/namenode.yaml" do 
  source "metrics/namenode.yaml"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode 500
end
