libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')
require 'resolv'

ndb_connectstring()

package_url = node[:dal][:download_url]
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config[:file_cache_path]}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "0755"
  # TODO - checksum
  action :create_if_missing
end

hin = "#{node[:hadoop][:home]}/.#{base_package_filename}_dal_downloaded"
base_name = File.basename(base_package_filename, ".tgz")
# Extract and install hadoop
bash 'extract-hadoop' do
  user "root"
  code <<-EOH
	tar -zxf #{cached_package_filename} -C #{node[:hadoop][:home]}/shared/yarn/jars
        chown -RL #{node[:hdfs][:user]}:#{node[:hadoop][:group]} #{node[:hadoop][:home]}/shared/yarn/jars
        rm #{node[:hadoop][:home]}/etc/hadoop/ndb.props
        touch #{hin}
	EOH
  not_if { ::File.exist?("#{hin}") }
end


template "#{node[:hadoop][:home]}/etc/hadoop/ndb.props" do
  source "ndb.props.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connect_string],
              :mysql_host => node[:ndb][:connect_string].split(":").first,
            })
end
