require 'resolv'

ndb_connectstring()
my_ip = my_private_ip()

group node['hops']['secure_group'] do
  action :create
  not_if "getent group #{node['hops']['password']['group']}"
end

directory "#{node.hops.dir}/ndb-hops-#{node.hops.version}-#{node.ndb.version}" do
  owner node.hops.hdfs.user
  group node.hops.group
  mode "750"
  action :create
end

link "#{node.hops.dir}/ndb-hops" do
  owner node.hops.hdfs.user
  group node.hops.group
  to "#{node.hops.dir}/ndb-hops-#{node.hops.version}-#{node.ndb.version}"
end


package_url = node.dal.download_url
base_filename = File.basename(package_url)

remote_file "#{node.hops.dir}/ndb-hops/#{base_filename}" do
  source package_url
  owner node.hops.hdfs.user
  group node.hops.group
  mode "0755"
  # TODO - checksum
  action :create_if_missing
end


hops_ndb "extract_ndb_hops" do
  base_filename base_filename
  action :install_ndb_hops
end

link "#{node.hops.dir}/ndb-hops/ndb-dal.jar" do
  owner node.hops.hdfs.user
  group node.hops.group
  to "#{node.hops.dir}/ndb-hops/ndb-dal-#{node.hops.version}-#{node.ndb.version}.jar"
end


mysql_ip = my_ip
if node.mysql.localhost == "true"
  mysql_ip = "localhost"
end

template "#{node.hops.home}/etc/hadoop/ndb.props" do
  source "ndb.props.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['secure_group']
  mode "750"
  variables({
              :ndb_connectstring => node.ndb.connectstring,
              :mysql_host => mysql_ip
            })
end

# If a MySQL server has been installed locally, then install the tables
  
hops_ndb "install" do
  action :install_hops
  only_if { ::File.exist? "#{node.ndb.scripts_dir}/mysql-client.sh" }
end

#
# Format the NameNode if a NameNode is being installed on this host
#
if node['hops'].attribute?('nn') == true && node['hops']['nn'].attribute?(:private_ips) == true

  for script in node.hops.nn.scripts
    template "#{node.hops.home}/sbin/#{script}" do
      source "#{script}.erb"
      owner node.hops.hdfs.user
      group node.hops.group
      mode 0770
    end
  end 


  Chef::Log.info "NameNode format option: #{node.hops.nn.format_options}"

  template "#{node.hops.home}/sbin/format-nn.sh" do
    source "format-nn.sh.erb"
    owner node.hops.hdfs.user
    group node.hops.group
    mode 0770
    variables({
                :format_opts => node.hops.nn.format_options
              })
  end

  
  my_ip = my_private_ip()

  #  for nn_ip in node['hops']['nn']['private_ips']
  if my_ip.eql? node['hops']['nn']['private_ips'][0]
    # Wait for db to start accepting requests (can be slow sometimes)
    include_recipe "hops::format"
  end
else
  raise "Error. There is no NameNode recipe defined in the cluster definition. Add hops::nn to the cluster.yml file."
end

