include_recipe "hops::default"

# Intall the needed packages
case node['platform_family']
when 'debian'
  package 'fuse'
  package 'libfuse-dev'
when 'rhel'
  package 'fuse'
  package 'fuse-libs'
end

service_name="hopsfsmount"

# Allow non root users to mount file systems 
bash "fuseconfig" do
  user "root" 
  code <<-EOH
    echo "user_allow_other" >>  /etc/fuse.conf
  EOH
  not_if "grep '^user_allow_other' /etc/fuse.conf"
end

directory node['hops']['fuse']['staging_folder'] do
  action :create
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0750"
  recursive true
end


bash "unmount-hopsfs" do
  user "root" 
  ignore_failure true
  code <<-EOH
    systemctl stop #{service_name}
    su - #{node['hops']['hdfs']['user']} -c "#{node['hops']['sbin_dir']}/umount-hopsfs.sh"
  EOH
  not_if node['install']['current_version'].empty?
end


directory node['hops']['fuse']['mount_point'] do
  action :create
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0755"
  recursive true
end


# download fuse mount bin
fuse_mount_bin_url = node['hops']['fuse']['dist_url']
bin_name = File.basename(fuse_mount_bin_url)
fuse_mount_bin = "#{node['hops']['sbin_dir']}/#{bin_name}"

remote_file fuse_mount_bin do
  source fuse_mount_bin_url
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode '0755'
  action :create
end

link "#{node['hops']['sbin_dir']}/hops-fuse-mount" do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  to "#{fuse_mount_bin}"
end

# nn address
my_ip = my_private_ip()
if service_discovery_enabled()
  rpc_namenode_fqdn = consul_helper.get_service_fqdn("rpc.namenode")
else
  if node['hops']['nn']['private_ips'].include?(my_ip)
    rpc_namenode_fqdn = my_ip
  else
    rpc_namenode_fqdn = private_recipe_ip("hops", "nn")
  end
end

# creating script to mount FS
template "#{node['hops']['sbin_dir']}/mount-hopsfs.sh" do
  source "mount-hopsfs.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "750"
  variables({
    :nn_address => rpc_namenode_fqdn,
    :fuse_mount_bin => "#{node['hops']['sbin_dir']}/hops-fuse-mount",
    :umount_cmd => "#{node['hops']['sbin_dir']}/umount-hopsfs.sh"
  })
  action :create
end

template "#{node['hops']['sbin_dir']}/umount-hopsfs.sh" do
  source "umount-hopsfs.sh.erb"
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "750"
  variables({
    :nn_address => rpc_namenode_fqdn,
    :fuse_mount_bin => "#{node['hops']['sbin_dir']}/hops-fuse-mount"
  })
  action :create
end

# create service for it

deps = ""
if service_discovery_enabled()
  deps += "consul.service "
end
if exists_local("hops", "nn") 
  deps += "namenode.service "
end  

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/#{service_name}.service"
when "debian"
  systemd_script = "/lib/systemd/system/#{service_name}.service"
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
end

kagent_config "#{service_name}" do
  action :systemd_reload
end

if node['kagent']['enabled'] == "true"
  kagent_config service_name do
    service "HDFS"
    log_file "#{node['hops']['logs_dir']}/fuse-mount.log"
  end
end
