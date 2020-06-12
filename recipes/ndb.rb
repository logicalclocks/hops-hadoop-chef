include_recipe "hops::_config"
require 'resolv'

ndb_connectstring()
my_ip = my_private_ip()

directory "#{node['hops']['dir']}/ndb-hops-#{node['hops']['version']}-#{node['ndb']['version']}" do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "750"
  action :create
end

link "#{node['hops']['dir']}/ndb-hops" do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  to "#{node['hops']['dir']}/ndb-hops-#{node['hops']['version']}-#{node['ndb']['version']}"
end

flyway_tgz = File.basename(node['hops']['flyway_url'])
flyway =  "flyway-" + node['hops']['flyway']['version']

remote_file "#{Chef::Config['file_cache_path']}/#{flyway_tgz}" do
  user node['hops']['hdfs']['user']
  group node['hops']['group']
  source node['hops']['flyway_url']
  mode 0755
  action :create_if_missing
end

flyway_basedir="#{node['hops']['dir']}/ndb-hops"

bash "unpack_flyway" do
  user "root"
  code <<-EOF
    set -e
    cd #{Chef::Config['file_cache_path']}
    tar -xzf #{flyway_tgz}
    mv #{flyway} #{flyway_basedir}
    cd #{flyway_basedir}
    chown -R #{node['hops']['hdfs']['user']}:#{node['hops']['group']} flyway*
    rm -rf flyway
    ln -s #{flyway} flyway
  EOF
  not_if { ::File.exists?("#{flyway_basedir}/flyway/flyway") }
end

template "#{flyway_basedir}/flyway/conf/flyway.conf" do
  source "flyway.conf.erb"
  owner node['hops']['hdfs']['user']
  mode 0750
  action :create  
end

directory "#{flyway_basedir}/flyway/undo" do
  owner node['hops']['hdfs']['user']
  mode "770"
  action :create
end

remote_file "#{flyway_basedir}/flyway/sql/V0.0.2__initial_tables.sql" do
  source "#{node['hops']['schema_dir']}/schema.sql"
  owner node['hops']['hdfs']['user']
  headers get_ee_basic_auth_header()
  sensitive true
  mode 0750
  action :create_if_missing
end

versions = node['hops']['versions'].split(/\s*,\s*/)
previous_version=""
if versions.any?
   previous_version=versions.last
end

myVersion = node['hops']['version']
flyway_version = myVersion.sub("-SNAPSHOT", "")
versions.push(flyway_version)

prev="2.8.2.1"
for version in versions do
  # Handle versions that are of type X.Y.Z-RC or X.Y.Z-EE-RC
  version = version.split("-")[0]
  remote_file "#{flyway_basedir}/flyway/sql/V#{version}__hops.sql" do
    source "#{node['hops']['schema_dir']}/update-schema_#{prev}_to_#{version}.sql"
    owner node['hops']['hdfs']['user']
    headers get_ee_basic_auth_header()
    sensitive true
    mode 0750
    action :create_if_missing
  end
  prev=version
end

package_url = node['dal']['download_url']
base_filename = File.basename(package_url)

remote_file "#{node['hops']['dir']}/ndb-hops/#{base_filename}" do
  source package_url
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  headers get_ee_basic_auth_header()
  sensitive true
  mode "0755"
  # TODO - checksum
  action :create_if_missing
end

hops_ndb "extract_ndb_hops" do
  base_filename base_filename
  action :install_ndb_hops
end

link "#{node['hops']['dir']}/ndb-hops/ndb-dal.jar" do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  to "#{node['hops']['dir']}/ndb-hops/ndb-dal-#{node['hops']['version']}-#{node['ndb']['version']}.jar"
end

template "#{node['hops']['home']}/etc/hadoop/ndb.props" do
  source "ndb.props.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['secure_group']
  mode "750"
  variables({
              :ndb_connectstring => node['ndb']['connectstring'],
            })
end

#
# A MySQL server should have been installed locally -  install the tables and rows. But only from 1 host.
#
if my_ip.eql? node['hops']['ndb']['private_ips'][0]
  hops_ndb "install" do
    action :install_hops
  end
end

#
# Format the NameNode if a NameNode is being installed on this host
#
if node['hops'].attribute?('nn') == true && node['hops']['nn'].attribute?(:private_ips) == true

  for script in node['hops']['nn']['scripts']
    template "#{node['hops']['home']}/sbin/#{script}" do
      source "#{script}.erb"
      owner node['hops']['hdfs']['user']
      group node['hops']['group']
      mode 0700
    end
  end 


  Chef::Log.info "NameNode format option: #{node['hops']['nn']['format_options']}"

  template "#{node['hops']['home']}/sbin/format-nn.sh" do
    source "format-nn.sh.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode 0700
    variables({
        :format_opts => node['hops']['nn']['format_options']
    })
  end

  
  #  for nn_ip in node['hops']['nn']['private_ips']
  if my_ip.eql? node['hops']['nn']['private_ips'][0]
    # Wait for db to start accepting requests (can be slow sometimes)
    include_recipe "hops::format"
  end
else
  raise "Error. There is no NameNode recipe defined in the cluster definition. Add hops::nn to the cluster.yml file."
end
