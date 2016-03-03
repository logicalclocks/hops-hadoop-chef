require 'resolv'

include_recipe "hops::wrap"

ndb_connectstring()
my_ip = my_private_ip()

directory "#{node.apache_hadoop.dir}/ndb-hops-#{node.apache_hadoop.version}-#{node.ndb.version}" do
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  action :create
  recursive true
end

link "#{node.apache_hadoop.dir}/ndb-hops" do
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  to "#{node.apache_hadoop.dir}/ndb-hops-#{node.apache_hadoop.version}-#{node.ndb.version}"
end


package_url = node.dal.download_url
base_filename = File.basename(package_url)

remote_file "#{Chef::Config.file_cache_path}/#{base_filename}" do
  source package_url
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "0755"
  # TODO - checksum
  action :create_if_missing
end


hops_ndb "extract_ndb_hops" do
  base_filename base_filename
  action :install_ndb_hops
end

link "#{node.apache_hadoop.dir}/ndb-hops/ndb-dal.jar" do
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  to "#{node.apache_hadoop.dir}/ndb-hops/ndb-dal-#{node.apache_hadoop.version}-#{node.ndb.version}.jar"
end


template "#{node.apache_hadoop.home}/etc/hadoop/ndb.props" do
  source "ndb.props.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  variables({
              :ndb_connectstring => node.ndb.connectstring,
              :mysql_host => my_ip
            })
end

# If a MySQL server has been installed locally, then install the tables
  
  hops_ndb "install" do
    action :install_hops
  only_if { ::File.exist? "#{node.ndb.scripts_dir}/mysql-client.sh" }
  end
