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
    user node[:ndb][:user]
    code <<-EOF
    set -e
    #{node[:ndb][:scripts_dir]}/mysql-client.sh -e \"CREATE DATABASE IF NOT EXISTS #{node[:hadoop][:db]}\"
    #{node[:ndb][:scripts_dir]}/mysql-client.sh #{node[:hadoop][:db]} < "#{node[:hadoop][:conf_dir]}/hops.sql"
    EOF
    new_resource.updated_by_last_action(true)
    not_if "#{node[:ndb][:scripts_dir]}/mysql-client.sh #{node[:hadoop][:db]} -e \"show create table hdfs_block_infos;\""
  end

end
