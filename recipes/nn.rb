include_recipe "hops::default"

my_ip = my_private_ip()

nnPort = node['hops']['nn']['port']

group node['hops']['secure_group'] do
  action :modify
  members ["#{node['hops']['hdfs']['user']}"]
  append true
end

if node.attribute?('hopsworks')
  if node['hopsworks'].nil? == false && node['hopsworks']['default'].nil? == false && node['hopsworks']['default']['private_ips'].nil? == false
    hopsworksNodes = node['hopsworks']['default']['private_ips'].join(",")
  end
end

if node['hops']['nn']['private_ips'].length > 1
  allNNs = node['hops']['nn']['private_ips'].join(":#{nnPort},") + ":#{nnPort}"
else
  allNNs = "#{node['hops']['nn']['private_ips'][0]}" + ":#{nnPort}"
end

hopsworks_ip = private_recipe_ip("hopsworks", "default")

if node['hops']['tls']['crl_input_uri'].empty?
  hopsworks_crl_uri = "RPC TLS NOT ENABLED"
  if node['hops']['tls']['enabled'].eql? "true"
    hopsworks_crl_uri = "Could not access hopsworks-chef"
    if node.attribute?("hopsworks")
      hopsworks_ip = private_recipe_ip("hopsworks", "default")
      hopsworks_port = "8181"
      if node['hopsworks'].attribute?(:secure_port)
        hopsworks_port = node['hopsworks']['secure_port']
      end
      hopsworks_crl_uri = "https://#{hopsworks_ip}:#{hopsworks_port}/intermediate.crl.pem"
    end
  end
else
  hopsworks_crl_uri = node['hops']['tls']['crl_input_uri']
end

include_recipe "hops::default"

myNN = "#{my_ip}:#{nnPort}"
template "#{node['hops']['conf_dir']}/core-site.xml" do
  source "core-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  variables({
              :firstNN => "hdfs://" + myNN,
              :hopsworks => hopsworksNodes,
              :hopsworksUser => node['hopsworks']['user'],
              :livyUser => node['livy']['user'],
              :hiveUser => node['hive2']['user'],
              :jupyterUser => node['jupyter']['user'],
              :allNNs => myNN,
              :rpcSocketFactory => node['hops']['hadoop']['rpc']['socket']['factory'],
              :hopsworks_crl_uri => hopsworks_crl_uri
            })
end

cache = "true"
if node['hops']['nn']['cache'].eql? "false"
   cache = "false"
end

partition_key = "true"
if node['hops']['nn']['partition_key'].eql? "false"
   partition_key = "false"
end

nnHTTPAddress = "#{my_ip}:#{node['hops']['nn']['http_port']}"

template "#{node['hops']['conf_dir']}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "755"
  cookbook "hops"
  variables({
              :firstNN => myNN,
              :cache => cache,
              :partition_key => partition_key,
              :nnHTTPAddress => nnHTTPAddress
            })
  action :create
end

template "#{node['hops']['home']}/sbin/root-drop-and-recreate-hops-db.sh" do
  source "root-drop-and-recreate-hops-db.sh.erb"
  owner "root"
  mode "700"
  action :create  
end

template "#{node['hops']['home']}/sbin/drop-and-recreate-hops-db.sh" do
  source "drop-and-recreate-hops-db.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "771"
  action :create  
end


template "#{node['hops']['home']}/sbin/root-test-drop-full-recreate.sh" do
  source "root-test-drop-full-recreate.sh.erb"
  owner "root"
  mode "700"
end

service_name="namenode"

if node['hops']['systemd'] == "true"

  case node['platform_family']
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

  file systemd_script do
    action :delete
    ignore_failure true
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0664
    action :create
if node['services']['enabled'] == "true"
    notifies :enable, "service[#{service_name}]"
end
    notifies :restart, "service[#{service_name}]"
  end

  kagent_config "#{service_name}" do
    action :systemd_reload
    not_if "systemctl status namenode"
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
if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => "#{service_name}")
end
    notifies :restart, resources(:service => "#{service_name}"), :immediately
  end
end



if node['kagent']['enabled'] == "true"
  kagent_config service_name do
    service "HDFS"
    config_file "#{node['hops']['conf_dir']}/hdfs-site.xml"
    log_file "#{node['hops']['logs_dir']}/hadoop-#{node['hops']['hdfs']['user']}-#{service_name}-#{node['hostname']}.log"
    web_port node['hops']['nn']['http_port']
  end
end

ruby_block 'wait_until_nn_started' do
  block do
     sleep(10)
  end
  action :run
end

tmp_dirs   = [ "/tmp", node['hops']['hdfs']['user_home'], node['hops']['hdfs']['user_home'] + "/" + node['hops']['hdfs']['user'] ]

# Only the first NN needs to create the directories
if my_ip.eql? node['hops']['nn']['private_ips'][0]
  for d in tmp_dirs
    hops_hdfs_directory d do
      action :create_as_superuser
      owner node['hops']['hdfs']['user']
      group node['hops']['group']
      mode "1775"
    end
  end

  # Add 'glassfish' to 'hdfs' superusers group
    hops_hdfs_directory "#{node['hops']['hdfs']['user_home']}/#{node['hopsworks']['user']}" do
      action :create_as_superuser
      owner node['hopsworks']['user']
      group node['hops']['group']
      mode "1750"
    end

    # Create weblogs dir for Glassfish
    hops_hdfs_directory "#{node['hops']['hdfs']['user_home']}/#{node['hopsworks']['user']}/webserver_logs" do
      action :create_as_superuser
      owner node['hopsworks']['user']
      group node['hops']['group']
      mode "1750"
    end
    
  exec = "#{node['ndb']['scripts_dir']}/mysql-client.sh"
  bash 'insert_hopsworks_as_hdfs_superuser' do
    user "root"
    code <<-EOF
      #{exec} hops -e 'REPLACE INTO hdfs_users_groups VALUES((SELECT id FROM hdfs_users WHERE name=\"#{node['hopsworks']['user']}\"), (SELECT id FROM hdfs_groups WHERE name=\"#{node['hops']['hdfs']['user']}\"))'
    EOF
  end

end
