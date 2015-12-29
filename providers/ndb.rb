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
    #{node[:ndb][:scripts_dir]}/mysql-client.sh -e \"CREATE DATABASE IF NOT EXISTS #{node[:hadoop][:db]} CHARACTER SET latin1\"
    #{node[:ndb][:scripts_dir]}/mysql-client.sh #{node[:hadoop][:db]} < "#{node[:hadoop][:conf_dir]}/hops.sql"
    EOF
    new_resource.updated_by_last_action(true)
    not_if "#{node[:ndb][:scripts_dir]}/mysql-client.sh #{node[:hadoop][:db]} -e \"show create table hdfs_block_infos;\""
  end

end


action :install_ndb_hops do

  Chef::Log.info "Installing hops.sql on the mysql server"

    remote_file "#{node[:hadoop][:conf_dir]}/hops.sql" do
      source node[:dal][:schema_url]
      owner node[:hdfs][:user]
      group node[:hadoop][:group]
      mode "0775"
      action :create_if_missing
    end

  common="share/hadoop/common/lib"
  base_filename = "#{new_resource.base_filename}"
  hin = "#{node[:hadoop][:home]}/.#{base_filename}_dal_downloaded"
  bash 'extract-hadoop' do
    user node[:hdfs][:user]
    group node[:hadoop][:group]
    code <<-EOH
        set -e
        rm -f #{node[:hadoop][:home]}/#{common}/ndb-dal.jar
        cp #{Chef::Config[:file_cache_path]}/#{base_filename} #{node[:hadoop][:dir]}/ndb-hops/#{base_filename}
	ln -s #{node[:hadoop][:dir]}/ndb-hops/#{base_filename} #{node[:hadoop][:home]}/#{common}/ndb-dal.jar
        rm -f #{node[:hadoop][:home]}/etc/hadoop/ndb.props

	rm -f #{node[:hadoop][:home]}/lib/native/libndbclient.so
	ln -s #{node[:mysql][:base_dir]}/lib/libndbclient.so* #{node[:hadoop][:home]}/lib/native

	rm -f #{node[:hadoop][:home]}/lib/native/libhopsyarn.so
	ln -s #{node[:hadoop][:dir]}/ndb-hops/libhopsyarn.so #{node[:hadoop][:home]}/lib/native/libhopsyarn.so

        touch #{hin}
	EOH
    not_if { ::File.exist?("#{hin}") }
  end

  lib_url = node[:dal][:lib_url]
  lib = ::File.basename(lib_url)

 remote_file "#{node[:hadoop][:dir]}/ndb-hops-#{node[:hadoop][:version]}-#{node[:ndb][:version]}/#{lib}" do
   source lib_url
   owner node[:hdfs][:user]
   group node[:hadoop][:group]
   mode "0755"
   # TODO - checksum
   action :create_if_missing
 end

 link "#{node[:hadoop][:dir]}/ndb-hops/libhopsyarn.so" do
   owner node[:hdfs][:user]
   group node[:hadoop][:group]
   to "#{node[:hadoop][:dir]}/ndb-hops/libhopsyarn-#{node[:hadoop][:version]}-#{node[:ndb][:version]}.so"
 end





end
