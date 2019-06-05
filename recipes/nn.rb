include_recipe "hops::default"

template_ssl_server()

my_ip = my_private_ip()

group node['hops']['secure_group'] do
  action :modify
  members ["#{node['hops']['hdfs']['user']}"]
  append true
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

deps = ""
if exists_local("ndb", "mysqld")
  deps = "mysqld.service "
end
if exists_local("hopsmonitor", "default")
  deps += "influxdb.service"
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
