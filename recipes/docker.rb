# Install and start Docker

case node['platform_family']
when 'rhel'
  package 'lvm2'
  package 'device-mapper'
  package 'device-mapper-persistent-data'
  package 'device-mapper-event'
  package 'device-mapper-libs'
  package 'device-mapper-event-libs'

  remote_file '/etc/yum.repos.d/docker-ce.repo' do
    source 'https://download.docker.com/linux/centos/docker-ce.repo'
    retries 2
    owner 'root'
    group 'root'
    mode "0644"
    action :create_if_missing
  end
  package 'docker-ce'
when 'debian'
  package 'docker.io'
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
    nvidia_docker_packages = ["libnvidia-container1-1.0.5-1#{package_type}", "libnvidia-container-tools-1.0.5-1#{package_type}", "nvidia-container-toolkit-1.0.5-2#{package_type}", "nvidia-container-runtime-2.0.0-1.docker1.13.1#{package_type}", "nvidia-docker2_2.2.2-1.noarch.rpm"]
  when 'debian'
    nvidia_docker_packages = ["libnvidia-container1_1.0.7-1#{package_type}", "libnvidia-container-tools_1.0.7-1#{package_type}", "nvidia-container-toolkit_1.0.5-1#{package_type}", "nvidia-container-runtime_3.1.4-1#{package_type}", "nvidia-docker2_2.2.2-1_all.deb"]
  end
  nvidia_docker_packages.each do |pkg|
    remote_file "#{Chef::Config['file_cache_path']}/#{pkg}" do
      source "#{node['download_url']}/kube/nvidia/#{pkg}"
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
  directory node['hops']['docker_dir'] do
    owner 'root'
    group 'root'
    mode '0711'
    recursive true
    action :create
  end
end

# Configure Docker

directory '/etc/docker/' do
  owner 'root'
  group 'root'
  recursive true
end

template '/etc/docker/daemon.json' do
  source 'daemon.json.erb'
  owner 'root'
  mode '0755'
  action :create
end

# Start the docker deamon
service 'docker' do
  action [:enable, :restart]
end

