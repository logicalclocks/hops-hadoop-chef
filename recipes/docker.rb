# Install and start Docker
Chef::Recipe.send(:include, Hops::Helpers)

group 'docker' do
  gid node['hops']['docker']['group_id']
  action :create
  not_if "getent group docker"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

case node['platform_family']
when 'rhel'

  # During upgrades, there might be a previous version of docker (not -ce) which will conflict with 
  # The docker-ce package we will install below. 
  package ['docker', 'docker-common'] do
    retries 10
    retry_delay 30
    action :remove
    only_if "yum list installed docker.x86_64"
  end

  base_package_filename = File.basename(node['hops']['docker']['download_url']['centos'])
  cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

  remote_file cached_package_filename do
    source node['hops']['docker']['download_url']['centos']
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  bash "install_pkgs" do
    user 'root'
    group 'root'
    cwd Chef::Config['file_cache_path']
    code <<-EOH
       tar xf #{base_package_filename}
       cd #{node['hops']['docker_version']['centos']}
       yum install -y *.rpm
    EOH
    not_if "yum list installed docker-ce-#{node['hops']['docker_version']['centos']}.el7.x86_64"
  end
when 'debian'

  base_package_filename = File.basename(node['hops']['docker']['download_url']['ubuntu'])
  cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

  remote_file cached_package_filename do
    source node['hops']['docker']['download_url']['ubuntu']
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  # Additional dependencies needed, but dpkg doesn't know how to fetch them
  # from the repositories
  package ['pigz', 'bridge-utils', 'dns-root-data', 'dnsmasq-base', "libidn11-dev", 'ubuntu-fan'] do
    retries 10
    retry_delay 30
  end

  bash "install_pkgs" do
    user 'root'
    group 'root'
    cwd Chef::Config['file_cache_path']
    code <<-EOH
       tar xf #{base_package_filename}
       cd #{node['hops']['docker_version']['ubuntu']}
       dpkg -i *.deb
    EOH
    not_if "dpkg -l docker.io | grep #{node['hops']['docker_version']['ubuntu']}"
  end
end

if node['hops']['gpu'].eql?("false")
  if node.attribute?("cuda") && node['cuda'].attribute?("accept_nvidia_download_terms") && node['cuda']['accept_nvidia_download_terms'].eql?("true")
    node.override['hops']['gpu'] = "true"
  end
end

#delete the config file to not interfere with the package installation
#we recreate it after anyway.
file '/etc/docker/daemon.json' do
  action :delete
  only_if { File.exist? '/etc/docker/daemon.json' }
end

if node['hops']['gpu'].eql?("true")
  package_type = node['platform_family'].eql?("debian") ? "_amd64.deb" : ".x86_64.rpm"
  case node['platform_family']
  when 'rhel'
    nvidia_docker_packages = ["libnvidia-container1-1.12.1-1#{package_type}", "libnvidia-container-tools-1.12.1-1#{package_type}", "nvidia-container-toolkit-1.12.1-1#{package_type}", "nvidia-container-toolkit-base-1.12.1-1#{package_type}", "nvidia-docker2-2.12.0-1.noarch.rpm"]
  when 'debian'
    nvidia_docker_packages = ["libnvidia-container1_1.12.1-1#{package_type}", "libnvidia-container-tools_1.12.1-1#{package_type}", "nvidia-container-toolkit_1.12.1-1#{package_type}", "nvidia-container-toolkit-base_1.12.1-1#{package_type}", "nvidia-docker2_2.12.0-1_all.deb"]
  end
  nvidia_docker_packages.each do |pkg|
    remote_file "#{Chef::Config['file_cache_path']}/#{pkg}" do
      source "#{node['hops']['nvidia_pkgs']['download_url']}/#{pkg}"
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end
  end

  # Install packages & Platform specific configuration
  case node['platform_family']
  when 'rhel'

    bash "install_pkgs" do
      user 'root'
      group 'root'
      cwd Chef::Config['file_cache_path']
      code <<-EOH
        yum install -y #{nvidia_docker_packages.join(" ")}
        EOH
      not_if "yum list installed libnvidia-container1"
    end

  when 'debian'
    
    bash "install_pkgs" do
      user 'root'
      group 'root'
      cwd Chef::Config['file_cache_path']
      code <<-EOH
        apt install -y ./#{nvidia_docker_packages.join(" ./")}
        EOH
    end
  end
end

if !node['hops']['docker_dir'].eql?("/var/lib/docker")
  directory node['hops']['data_volume']['docker'] do
    owner 'root'
    group 'root'
    mode '0711'
    recursive true
    action :create
  end

  systemd_unit "docker.service" do
    action :stop
    only_if { conda_helpers.is_upgrade }
    only_if { File.directory?(node['hops']['docker_dir'])}
    not_if { File.symlink?(node['hops']['docker_dir'])}
  end

  bash 'move-docker-images' do
    user 'root'
    code <<-EOH
      set -e
      mv -f #{node['hops']['docker_dir']}/* #{node['hops']['data_volume']['docker']}
    EOH
    only_if { conda_helpers.is_upgrade }
    only_if { File.directory?(node['hops']['docker_dir']) }
    not_if { File.symlink?(node['hops']['docker_dir']) }
    not_if { Dir.empty?(node['hops']['docker_dir']) }
  end

  directory node['hops']['docker_dir'] do
    action :delete
    only_if { conda_helpers.is_upgrade }
    only_if { File.directory?(node['hops']['docker_dir']) }
    not_if { File.symlink?(node['hops']['docker_dir']) }
  end

  link node['hops']['docker_dir'] do
    owner 'root'
    group 'root'
    mode '0711'
    to node['hops']['data_volume']['docker']
  end
end

# Configure Docker

directory '/etc/docker/' do
  owner 'root'
  group 'root'
  recursive true
end

insecure_registries = node['hops']['docker']['insecure_registries'].split(",")
if service_discovery_enabled()
  registry_host = consul_helper.get_service_fqdn("registry")
  insecure_registries << "#{registry_host}:#{node['hops']['docker']['registry']['port']}"
end

# Special case where its a localhost installation for Ubuntu
# If we don't override Docker's DNS servers, in AWS we can't
# resolve our own hostname
override_dns = node['install']['localhost'].casecmp?("true") && node['platform_family'].eql?("debian")
dns_servers = ["127.0.0.53"]

docker_cgroup_driver = docker_cgroup_driver()
cgroup_parent = node['hops']['docker']['cgroup']['parent']
if docker_cgroup_driver.eql?("cgroupfs")
  cgroup_parent = "/#{cgroup_parent}"
end

template '/etc/docker/daemon.json' do
  source 'daemon.json.erb'
  owner 'root'
  mode '0755'
  action :create
  variables({
              :insecure_registries => insecure_registries,
              :override_dns => override_dns,
              :dns_servers => dns_servers,
              :docker_cgroup_driver => docker_cgroup_driver,
              :cgroup_parent => cgroup_parent
            })
end

cookbook_file node['hops']['docker']['hopsfsmount-seccomp-profile'] do
  source 'hopsfsmount_seccomp_profile.json'
  owner 'root'
  mode '0755'
  action :create
end


service_name='docker'

# Start the docker deamon
kagent_config service_name do
  action :systemd_reload
end

service service_name do
  action :enable
end

cmd = Mixlib::ShellOut.new('docker info | grep "apparmor"')
cmd.run_command
if cmd.error?
  node.override['hops']['docker']['apparmor-enabled'] = "false"
end

hopsfsmount_apparmor_profile="/etc/apparmor.d/#{node['hops']['docker']['hopsfsmount-apparmor-profile']}"
cookbook_file hopsfsmount_apparmor_profile do
  source 'hopsfsmount_apparmor_profile'
  owner 'root'
  mode '0755'
  action :create
  only_if { node['hops']['docker']['apparmor-enabled'].casecmp?("true") }
end

bash 'apply_hopsfsmount_apparmor_profile' do
  user 'root'
  code <<-EOH
      apparmor_parser -r -W #{hopsfsmount_apparmor_profile}
  EOH
  only_if { node['hops']['docker']['load-hopsfsmount-apparmor-profile'].casecmp?("true")}
  only_if { node['hops']['docker']['apparmor-enabled'].casecmp?("true") }
end
