include_recipe "hops::default"

template_ssl_server()

my_ip = my_private_ip()

group node['hops']['secure_group'] do
  action :modify
  members node['hops']['hdfs']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

crypto_dir = x509_helper.get_crypto_dir(node['hops']['hdfs']['user'])
kagent_hopsify "Generate x.509" do
  user node['hops']['hdfs']['user']
  crypto_directory crypto_dir
  action :generate_x509
  not_if { node["kagent"]["enabled"] == "false" }
end

file "#{node['hops']['conf_dir']}/dfs.exclude" do 
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "700"
  content node['hops']['dfs']['excluded_hosts'].gsub(',', "\n")
end

deps = ""
if service_discovery_enabled()
  deps += "consul.service "
end

if exists_local("ndb", "mysqld")
  deps += "mysqld.service "
end

if node['hops']['tls']['crl_enabled'].casecmp?("true") and exists_local("hopsworks", "default")
  deps += "glassfish-domain1.service "
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
    variables({
              :deps => deps
              })
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
  end
end

if service_discovery_enabled()
  # Register NameNode with Consul
  if node['hops']['tls']['enabled'].casecmp?("true")
    scheme = "https"
    http_port = node['hops']['nn']['https']['port']
  else
    scheme = "http"
    http_port = node['hops']['nn']['http_port']
  end

  consul_crypto_dir = x509_helper.get_crypto_dir(node['consul']['user'])
  template "#{node['hops']['bin_dir']}/consul/nn-health.sh" do
    source "consul/nn-health.sh.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode 0750
    variables({
      :key => "#{consul_crypto_dir}/#{x509_helper.get_private_key_pkcs8_name(node['consul']['user'])}",
      :certificate => "#{consul_crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['consul']['user'])}",
      :scheme => scheme,
      :http_port => http_port
    })
  end

  consul_service "Registering NameNode with Consul" do
    service_definition "consul/nn-consul.hcl.erb"
    template_variables({
      :http_port => http_port
    })
    action :register
  end
end

ruby_block 'wait_until_nn_started' do
  block do
     sleep(10)
  end
  action :run
end

dirs = [ "/tmp", node['hops']['hdfs']['user_home'], node['hops']['hdfs']['user_home'] + "/" + node['hops']['hdfs']['user'], node['hops']['hdfs']['apps_dir'] ]

# Only the first NN needs to create the directories
if my_ip.eql? node['hops']['nn']['private_ips'][0]
  for d in dirs
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


  ts = Time.new.strftime("%Y_%m_%d_%H_%M")

  if node['ndb']['nvme']['undofile_size'] != ""
    bash 'add_disk_undo_file' do
      user node['ndb']['user']
      code <<-EOF
        #{node['ndb']['scripts_dir']}/mysql-client.sh INFORMATION_SCHEMA -e "SELECT MAXIMUM_SIZE from FILES WHERE FILE_TYPE like 'UNDO LOG' AND FILE_NAME like 'undo_%'" | sed 's/\t/,/g'  > /tmp/undo.csv
        # all of the undo file sizes are now in /tmp/undo.csv. Sum them up using awk, result on last line.
        existing_size=$(awk -F"," '{print;x+=$1}END{print x}' /tmp/undo.csv | tail -1)
        desired_size="#{node['ndb']['nvme']['undofile_size']}"
        size=${desired_size/M/000000}
        remaining=$(($size - $existing_size))
        # add a new undo file if remaining is > 1MB
        if [ $remaining -gt 1000000 ] ; then
           echo "ALTER LOGFILE GROUP lg_1 ADD UNDOFILE 'undo_#{ts}.log' INITIAL_SIZE ${remaining} ENGINE NDBCLUSTER" > /tmp/undo.sql
           #{node['ndb']['scripts_dir']}/mysql-client.sh < /tmp/undo.sql
           rm /tmp/undo.sql
        fi
      EOF
    end
  end


  if node['ndb']['nvme']['logfile_size'] != ""
    bash 'add_disk_data_file' do
      user node['ndb']['user']
      timeout 7200
      code <<-EOF
        #{node['ndb']['scripts_dir']}/mysql-client.sh INFORMATION_SCHEMA -e "SELECT MAXIMUM_SIZE from FILES WHERE FILE_TYPE like 'DATAFILE' AND FILE_NAME like 'ts_1_data_file_%'" | sed 's/\t/,/g'  > /tmp/datafile.csv
        # all of the datafile file sizes are now in /tmp/datafile.csv. Sum them up using awk, result on last line.
        existing_size=$(awk -F"," '{print;x+=$1}END{print x}' /tmp/datafile.csv | tail -1)
        desired_size="#{node['ndb']['nvme']['logfile_size']}"
        size=${desired_size/M/000000}
        remaining=$(($size - $existing_size))
        # add a new data file if remaining is > 1MB
        if [ $remaining -gt 1000000 ] ; then
           echo "ALTER TABLESPACE ts_1 ADD DATAFILE 'ts_1_data_file_#{ts}.dat' INITIAL_SIZE ${remaining}" > /tmp/datafile.sql
           #{node['ndb']['scripts_dir']}/mysql-client.sh < /tmp/datafile.sql
           rm /tmp/datafile.sql
        fi
      EOF
    end
  end

  if node['hops']['nn']['root_dir_storage_policy'] != ""
    exec = "#{node['hops']['bin_dir']}/hdfs storagepolicies -setStoragePolicy -path / -policy "
    bash 'set_root_storage_plicy' do
      user node['hops']['hdfs']['user']
      code <<-EOF
        #{exec} "#{node['hops']['nn']['root_dir_storage_policy']}\"
      EOF
    end
  end

end
