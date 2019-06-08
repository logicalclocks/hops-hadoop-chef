action :install_hops do

  new_resource.updated_by_last_action(false)

  ndb_waiter "wait_mysql_started" do
    action :wait_until_cluster_ready
  end

  ndb_mysql_basic "mysqld_start_hop_install" do
    wait_time 10
    action :wait_until_started
  end

  bash "mysql-install-hops" do
    user "root"
    code <<-EOF
    set -e
    #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"CREATE DATABASE IF NOT EXISTS #{node['hops']['db']} CHARACTER SET latin1\"
    EOF
  end
  flyway_basedir="#{node['hops']['dir']}/ndb-hops"

  template "#{flyway_basedir}/flyway.sql" do
    source "flyway.sql.erb"
    owner node['hops']['hdfs']['user']
    mode 0750
    action :create
  end


  flyway_dir="#{node['hops']['dir']}/ndb-hops/flyway"

  bash "flyway_baseline" do
    user "root"
    code <<-EOF
    set -e
    cd #{flyway_dir}
    #{node['ndb']['scripts_dir']}/mysql-client.sh #{node['hops']['db']} < #{node['hops']['dir']}/ndb-hops/flyway.sql
    #{flyway_dir}/flyway baseline
  EOF
    not_if "#{node['ndb']['scripts_dir']}/mysql-client.sh #{node['hops']['db']} -e 'show tables' | grep flyway_schema_history"
  end

  bash "flyway_migrate" do
    user "root"
    code <<-EOF
    set -e
    cd #{flyway_dir}
    #{flyway_dir}/flyway migrate
  EOF
  end


  if node['ndb']['nvme']['logfile_size'] != ""
    bash 'add_disk_data_files' do
      user node['ndb']['user']
      code <<-EOF
        #{node['ndb']['scripts_dir']}/mysql-client.sh < "ALTER TABLESPACE ts_1 ADD DATAFILE 'data_2.dat' INITIAL_SIZE #{node['ndb']['nvme']['logfile_size']}
      EOF
      new_resource.updated_by_last_action(true)
      not_if "test -f #{node['ndb']['nvme']['mount_base_dir']}/#{node['ndb']['nvme']['mount_disk_prefix']}0/#{node['ndb']['ndb_disk_columns_dir_name']}/data_2.dat"
  end
  
  
end


action :install_ndb_hops do

  Chef::Log.info "Installing hops sql on the mysql server"

  common="share/hadoop/common/lib"
  base_filename = "#{new_resource.base_filename}"

  lib_url = node['dal']['lib_url']
  lib = ::File.basename(lib_url)

  remote_file "#{node['hops']['dir']}/ndb-hops-#{node['hops']['version']}-#{node['ndb']['version']}/#{lib}" do
    source lib_url
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0755"
    # TODO - checksum
    action :create_if_missing
  end

  link "#{node['hops']['dir']}/ndb-hops/libhopsyarn.so" do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    to "#{node['hops']['dir']}/ndb-hops/#{lib}"
  end

  link "#{node['hops']['home']}/#{common}/ndb-dal.jar" do
    action :delete
    only_if "test -L #{node['hops']['home']}/#{common}/ndb-dal.jar"
  end
  link "#{node['hops']['home']}/#{common}/ndb-dal.jar" do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    to "#{node['hops']['dir']}/ndb-hops/#{base_filename}"
  end

  link "#{node['hops']['home']}/#{common}/nvidia-management.jar" do
    action :delete
    only_if "test -L #{node['hops']['home']}/#{common}/nvidia-management.jar"
  end
  link "#{node['hops']['home']}/#{common}/nvidia-management.jar" do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    to "#{node['hops']['dir']}/ndb-hops/nvidia-management.jar"
  end


  link "#{node['hops']['home']}/lib/native/libndbclient.so" do
    action :delete
    only_if "test -L #{node['hops']['home']}/lib/native/libndbclient.so"
  end
  link "#{node['hops']['home']}/lib/native/libndbclient.so" do
    owner "root"
    group "root"
    to "#{node['mysql']['dir']}/mysql/lib/libndbclient.so"
  end

  link "#{node['hops']['home']}/lib/native/libhopsyarn.so" do
    action :delete
    only_if "test -L #{node['hops']['home']}/lib/native/libhopsyarn.so"
  end
  link "#{node['hops']['home']}/lib/native/libhopsyarn.so" do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    to "#{node['hops']['dir']}/ndb-hops-#{node['hops']['version']}-#{node['ndb']['version']}/libhopsyarn-#{node['hops']['version']}-#{node['ndb']['version']}.so"
  end

end
