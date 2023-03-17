include_recipe "java"
include_recipe "hops::_config"

Chef::Recipe.send(:include, Hops::Helpers)

flyingduck_in_cloud = exists_local("hops", "client") and exists_local("flyingduck", "default") and !node['install']['cloud'].empty? 

if not node["hopsworks"]["default"].attribute?("public_ips") and not flyingduck_in_cloud
  Chef::Log.warn("Hopsworks cookbook was not loaded, disabling Hops TLS and JWT support!")
  node.override['hops']['tls']['enabled'] = "false"
  node.override['hops']['rmappsecurity']['jwt']['enabled'] = "false"
end

require 'resolv'

nnPort=node['hops']['nn']['port']
hops_group=node['hops']['group']
my_ip = my_private_ip()

ndb_connectstring()

if service_discovery_enabled()
  ## Do not try to discover Hopsworks before it has been actual deployed
  ## default recipe is included by hops::ndb
  run_list = node.primary_runlist
  run_discovery_recipes = ['recipe[hops::client]', 'recipe[hops::dn]', 'recipe[hops::jhs]', 'recipe[hops::nm]', 'recipe[hops::nn]', 'recipe[hops::ps]', 'recipe[hops::rm]', 'recipe[hops::rt]', 'recipe[hops::fuse_mnt]']
  run_discovery = false
  for dr in run_discovery_recipes do
    if run_list.include?(dr)
      run_discovery = true
      break
    end
  end

  # Do no try to discover Hopsworks if building flyingduck on mysqld nodes in the cloud, no Hopsworks server is running
  if flyingduck_in_cloud 
    run_discovery = false
  end 

  hopsworks_port = "8182"
  if run_discovery
    ruby_block 'Discover Hopsworks port' do
      block do
        _, hopsworks_port = consul_helper.get_service("glassfish", ["http", "hopsworks"])
        if hopsworks_port.nil?
          raise "Could not get Hopsworks port from local Consul agent. Verify Hopsworks is running with service name: glassfish and tags: [http, hopsworks]"
        end
      end
    end
  end

  glassfish_fqdn = consul_helper.get_service_fqdn("glassfish")
  rpc_namenode_fqdn = consul_helper.get_service_fqdn("rpc.namenode")
  resourcemanager_fqdn = consul_helper.get_service_fqdn("resourcemanager")
  zookeeper_fqdn = consul_helper.get_service_fqdn("client.zookeeper")
else
  ## Service Discovery is disabled

  glassfish_fqdn = ""
  if node.attribute?("hopsworks")
    glassfish_fqdn = private_recipe_ip("hopsworks", "default")
    hopsworks_port = "8181"	
    if node['hopsworks'].attribute?('https') and node['hopsworks']['https'].attribute?('port')	
        hopsworks_port = node['hopsworks']['https']['port']	
    end
  end

  if node['hops']['nn']['private_ips'].include?(my_ip)
    rpc_namenode_fqdn = my_ip
  else
    rpc_namenode_fqdn = private_recipe_ip("hops", "nn")
  end

  if node['hops']['rm']['private_ips'].include?(my_ip)	
    resourcemanager_fqdn = my_ip;
  else
    resourcemanager_fqdn = private_recipe_ip("hops","rm")	
  end
  zookeeper_fqdn = private_recipe_ip('kzookeeper', 'default')
end

if exists_local("hops", "rm")
  if node['hops']['rm']['private_ips'].include?(my_ip)	
    resourcemanager_fqdn = my_ip;
  else
    resourcemanager_fqdn = private_recipe_ip("hops","rm")	
  end
end

rpcSocketFactory = "org.apache.hadoop.net.StandardSocketFactory"
hopsworks_crl_uri = "RPC TLS NOT ENABLED"
if node['hops']['tls']['enabled'].eql? "true"
  rpcSocketFactory = node['hops']['hadoop']['rpc']['socket']['factory']
end

node.override['hops']['hadoop']['rpc']['socket']['factory'] = rpcSocketFactory

nn_rpc_endpoint = "#{rpc_namenode_fqdn}:#{nnPort}"
defaultFS = "hdfs://#{rpc_namenode_fqdn}:#{nnPort}"


hopsworksUser = "glassfish"
if node.attribute?("hopsworks")
  if node['hopsworks'].attribute?("user")
    hopsworksUser = node['hopsworks']['user']
  end
end
node.override['hopsworks']['user'] = hopsworksUser

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

flinkUser = "flink"
if node.attribute?('flink')
  if node['flink'].attribute?('user')
    flinkUser = node['flink']['user']
  end
end
node.override['flink']['user'] = flinkUser

flyingduckUser = "flyingduck"
if node.attribute?('flyingduck')
  if node['flyingduck'].attribute?('user')
    flyingduckUser = node['flyingduck']['user']
  end
end

template "#{node['hops']['conf_dir']}/log4j2.properties" do
  source "log4j2.properties.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "644"
  action :create
end

if node['ndb']['TransactionInactiveTimeout'].to_i < node['hops']['leader_check_interval_ms'].to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

sd_enabled = service_discovery_enabled() ? "true" : "false"
template "#{node['hops']['conf_dir']}/core-site.xml" do
  source "core-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "744"
  variables( lazy {
    {
     :defaultFS => defaultFS,
     :hopsworks => "https://#{glassfish_fqdn}:#{hopsworks_port}",
     :hopsworksUser => hopsworksUser,
     :livyUser => livyUser,
     :hiveUser => hiveUser,
     :flinkUser => flinkUser,
     :flyingduckUser => flyingduckUser,
     :nn_rpc_endpoint => nn_rpc_endpoint,
     :rpcSocketFactory => rpcSocketFactory,
     :hopsworks_crl_uri => "https://#{glassfish_fqdn}:#{hopsworks_port}#{node['hops']['tls']['crl_fetch_path']}",
     :service_discovery_enabled => sd_enabled,
     :my_ip => my_ip
    }
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

template "#{node['hops']['sbin_dir']}/set-env.sh" do
  source "set-env.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['secure_group']
  mode "750"
  action :create
end

bind_ip = "0.0.0.0"
if conda_helpers.bind_services_private_ip
  bind_ip = my_ip
end

if node['install']['localhost'].casecmp?("true")
  nn_address = "localhost"
else 
  if node['hops']['nn']['private_ips'].include?(my_ip)
    # If I'm a NameNode set it to my fqdn or IP
    if service_discovery_enabled()
      nn_address = node['fqdn']
    else
      nn_address = my_ip
    end
  else
    # Otherwise use Service Discovery FQDN
    nn_address = rpc_namenode_fqdn
  end
end

location_domain_id = node['hops']['nn']['private_ips_domainIds'].has_key?(my_ip) ? node['hops']['nn']['private_ips_domainIds'][my_ip] : 0
template "#{node['hops']['conf_dir']}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "754"
  cookbook "hops"
  variables({
    :location_domain_id => location_domain_id,
    :bind_ip => bind_ip,
    :nn_address => nn_address
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

if node['hops']['yarn']['detect-hardware-capabilities'].casecmp?("true")
  node.override['hops']['yarn']['vcores'] = "-1"
  node.override['hops']['yarn']['memory_mbs'] = "-1"
end

ha_ids = (0...node['hops']['rm']['private_ips'].size()).to_a()
my_id = node['hops']['rm']['private_ips'].index(my_ip)

if node['hops']['gpu'].eql?("false")
  if node.attribute?("cuda") && node['cuda'].attribute?("accept_nvidia_download_terms") && node['cuda']['accept_nvidia_download_terms'].eql?("true")
    node.override['hops']['gpu'] = "true"
  end
end

template "#{node['hops']['conf_dir']}/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "744"
  variables( lazy {
    h = {}
    h[:resourcemanager_fqdn] = resourcemanager_fqdn
    h[:zookeeper_fqdn] = zookeeper_fqdn
    h[:ha_ids] = ha_ids
    h[:my_id] = my_id
    h[:bind_ip] = bind_ip
    h
  })
  action :create
end

template "#{node['hops']['conf_dir']}/resource-types.xml" do
  source "resource-types.xml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  cookbook "hops"
  mode "744"
  action :create
end


if node['hops']['docker']['enabled'].eql?("true")

  if service_discovery_enabled()
    registry_host=consul_helper.get_service_fqdn("registry")
  else
    begin
      registry_ip = private_recipe_ip("hops","docker_registry")
      registry_host = resolve_hostname(registry_ip)
    rescue
      registry_host = "localhost"
      Chef::Log.warn "could not find the docker registry ip!"
    end
  end

  trusted_registries = "#{registry_host}:#{node['hops']['docker']['registry']['port']}"
  
  unless node['hops']['docker']['trusted_registries'].eql?("")
    trusted_registries = "#{trusted_registries},#{node['hops']['docker']['trusted_registries']}"
  end

  docker_path = shell_out("which docker").stdout
end

template "#{node['hops']['conf_dir']}/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner "root"
  group node['hops']['group']
  cookbook "hops"
  mode "740"
  variables({
              :hops_group => hops_group,
              :trusted_registries => trusted_registries,
              :docker_path => docker_path
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

hdfs_user_home = conda_helpers.get_user_home(node['hops']['hdfs']['user'])
if not node['hops']['aws_access_key_id'].eql?("") and not node['hops']['aws_secret_access_key'].eql?("")
  directory "#{hdfs_user_home}/.aws" do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0755"
    action :create
  end
  
  template "#{hdfs_user_home}/.aws/credentials" do
    source "credentials.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "600"
    action :create
  end
end
