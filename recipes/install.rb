node.default['java']['jdk_version'] = 7
node.default['java']['install_flavor'] = "openjdk"
include_recipe "java"

kagent_bouncycastle "jar" do
end

group node[:hadoop][:group] do
  action :create
end

user node[:hdfs][:user] do
  supports :manage_home => true
  action :create
  home "/home/#{node[:hdfs][:user]}"
  system true
  shell "/bin/bash"
end

user node[:hadoop][:yarn][:user] do
  supports :manage_home => true
  home "/home/#{node[:hadoop][:yarn][:user]}"
  action :create
  system true
  shell "/bin/bash"
end

user node[:hadoop][:mr][:user] do
  supports :manage_home => true
  home "/home/#{node[:hadoop][:mr][:user]}"
  action :create
  system true
  shell "/bin/bash"
end

group node[:hadoop][:group] do
  action :modify
  members ["#{node[:hdfs][:user]}", "#{node[:hadoop][:yarn][:user]}", "#{node[:hadoop][:mr][:user]}"]
  append true
end

directory node[:hadoop][:dir] do
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "0775"
  recursive true
  action :create
end

case node[:platform_family]
when "debian"
package "openssh-server" do
 action :install
 options "--force-yes"
end

package "openssh-client" do
 action :install
 options "--force-yes"
end
when "rhel"

end

package_url = node[:hadoop][:download_url]
Chef::Log.info "Downloading hadoop binaries from #{package_url}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config[:file_cache_path]}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "0775"
  # TODO - checksum
  action :create_if_missing
end

base_name = File.basename(base_package_filename, ".tgz")
# Extract and install hadoop
bash 'extract-hadoop' do
  user "root"
  code <<-EOH
        rm -rf #{node[:hadoop][:dir]}/hadoop
	tar -xf #{cached_package_filename} -C #{node[:hadoop][:dir]}
        mv #{node[:hadoop][:dir]}/hadoop #{node[:hadoop][:home]}
# chown -L : traverse symbolic links
        ln -s #{node[:hadoop][:home]} #{node[:hadoop][:dir]}/hadoop
        chown -RL #{node[:hdfs][:user]}:#{node[:hadoop][:group]} #{node[:hadoop][:home]}
        touch #{node[:hadoop][:home]}/.downloaded
	EOH
  not_if { ::File.exist?("#{node[:hadoop][:home]}/.downloaded") }
end

 directory node[:hadoop][:logs_dir] do
   owner node[:hdfs][:user]
   group node[:hadoop][:group]
   mode "0775"
   action :create
 end

 directory node[:hadoop][:tmp_dir] do
   owner node[:hdfs][:user]
   group node[:hadoop][:group]
   mode "1777"
   action :create
 end

include_recipe "hops"
