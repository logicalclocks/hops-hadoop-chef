group node['kagent']['certs_group'] do
  action :create
  not_if "getent group #{node['kagent']['certs_group']}"
end


magic_shell_environment 'LD_LIBRARY_PATH' do
  value "#{node['hops']['base_dir']}/lib/native:$LD_LIBRARY_PATH"
end


case node['platform']
when "ubuntu"
 if node['platform_version'].to_f <= 14.04
   node.override['hops']['systemd'] = "false"
 end
end


# http://blog.cloudera.com/blog/2015/01/how-to-deploy-apache-hadoop-clusters-like-a-boss/
# Set Kernel parameters
sysctl_param 'vm.swappiness' do
  value node['hops']['kernel']['swappiness']
end

sysctl_param 'vm.overcommit_memory' do
  value node['hops']['kernel']['overcommit_memory']
  value
end

sysctl_param 'vm.overcommit_ratio' do
  value node['hops']['kernel']['overcommit_ratio']
end

sysctl_param 'net.core.somaxconn' do
  value node['hops']['kernel']['somaxconn']
end

#
# http://www.slideshare.net/vgogate/hadoop-configuration-performance-tuning
#
if node['platform_family'].eql?("redhat")
  bash "configure_os" do
     user "root"
     code <<-EOF
      echo "never" > /sys/kernel/mm/redhat_transparent_hugepages/defrag
     EOF
  end
end

include_recipe "java"

group node['hops']['group'] do
  action :create
  not_if "getent group #{node['hops']['group']}"
end

group node['hops']['secure_group'] do
  action :create
  not_if "getent group #{node['hops']['secure_group']}"
end

user node['hops']['hdfs']['user'] do
  home "/home/#{node['hops']['hdfs']['user']}"
  gid node['hops']['group']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['hdfs']['user']}"
end

user node['hops']['yarn']['user'] do
  home "/home/#{node['hops']['yarn']['user']}"
  gid node['hops']['group']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['yarn']['user']}"
end

user node['hops']['mr']['user'] do
  home "/home/#{node['hops']['mr']['user']}"
  gid node['hops']['group']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['mr']['user']}"
end

user node['hops']['yarnapp']['user'] do
  home "/home/#{node['hops']['yarnapp']['user']}"
  gid node['hops']['group']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['yarnapp']['user']}"
end


user node['hops']['rm']['user'] do
  home "/home/#{node['hops']['rm']['user']}"
  gid node['hops']['secure_group']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['rm']['user']}"
end

group node['hops']['secure_group'] do
  action :modify
  members ["#{node['hops']['rm']['user']}"]
  append true
end

group node['hops']['group'] do
  action :modify
  members ["#{node['hops']['hdfs']['user']}", "#{node['hops']['yarn']['user']}", "#{node['hops']['mr']['user']}", "#{node['hops']['yarnapp']['user']}", "#{node['hops']['rm']['user']}"]
  append true
end

group node['kagent']['certs_group'] do
  action :modify
  members ["#{node['hops']['hdfs']['user']}", "#{node['hops']['yarn']['user']}", "#{node['hops']['rm']['user']}", "#{node['hops']['mr']['user']}"]
  append true
end

case node['platform']
when 'ubuntu'
  package 'libsnappy1v5'
when 'centos'
  package 'snappy'
end

if node['hops']['native_libraries'].eql? "true"

  # build hadoop native libraries: http://www.drweiwang.com/build-hadoop-native-libraries/
  # g++ autoconf automake libtool zlib1g-dev pkg-config libssl-dev cmake

  include_recipe 'build-essential::default'
  include_recipe 'cmake::default'

    protobuf_url = node['hops']['protobuf_url']
    base_protobuf_filename = File.basename(protobuf_url)
    cached_protobuf_filename = "#{Chef::Config['file_cache_path']}/#{base_protobuf_filename}"

    remote_file cached_protobuf_filename do
      source protobuf_url
      owner node['hops']['hdfs']['user']
      group node['hops']['group']
      mode "0775"
      action :create_if_missing
    end

  protobuf_lib_prefix = "/usr"
  case node['platform_family']
  when "debian"
    package ['g++', 'autoconf', 'automake', 'libtool', 'zlib1g-dev', 'libssl-dev', 'pkg-config', 'maven']
  when "rhel"
    protobuf_lib_prefix = "/"

    # https://github.com/burtlo/ark
    ark "maven" do
      url "http://apache.mirrors.spacedump.net/maven/maven-3/#{node['maven']['version']}/binaries/apache-maven-#{node['maven']['version']}-bin.tar.gz"
      version "#{node['maven']['version']}"
      path "/usr/local/maven/"
      home_dir "/usr/local/maven"
 #     checksum  "#{node['maven']['checksum']}"
      append_env_path true
      owner "#{node['hops']['hdfs']['user']}"
    end

  end
   protobuf_name_no_extension = File.basename(base_protobuf_filename, ".tar.gz")
   protobuf_name = "#{protobuf_lib_prefix}/.#{protobuf_name_no_extension}_downloaded"
   bash 'extract-protobuf' do
      user "root"
      code <<-EOH
        set -e
        cd #{Chef::Config['file_cache_path']}
	tar -zxf #{cached_protobuf_filename}
        cd #{protobuf_name_no_extension}
        ./configure --prefix=#{protobuf_lib_prefix}
        make
        make check
        make install
        touch #{protobuf_name}
	EOH
     not_if { ::File.exist?("#{protobuf_name}") }
    end

end

# For LinuxContainerExecutor the the whole hadoop subtree should be own by root and not group writable.
# If another cookbook has created the directory before, it will be updaste to have the correct ownership/permissions
directory node['hops']['dir'] do
  owner "root"
  group node['hops']['group']
  mode "0755"
  action :create
end

dataDir=node['hops']['data_dir']
dataDir.gsub!("file://","")

directory dataDir do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0770"
  recursive true
  action :create
end

if "#{node['hops']['dn']['data_dir']}".include? ","
  dirs = node['hops']['dn']['data_dir'].split(",")
  for d in dirs do
    d.gsub!("file://","")    
    bash 'chown_datadirs_if_exist' do
      user "root"
      code <<-EOH
        set -e
        # -e tests for dir, file, symbolic link. It should be a dir.
        if [ ! -e #{d} ] ; then
           mkdir -p #{d}
        fi
        chown -R #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{d}
      EOH
    end
   end
else
  ddir=node['hops']['dn']['data_dir'] 
  ddir.gsub!("file://","")  
  directory ddir do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0770"
    recursive true
    action :create
  end
end

nndir=node['hops']['nn']['name_dir']
nndir.gsub!("file://","")  
directory nndir do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0770"
  recursive true
  action :create
end

primary_url = node['hops']['url']['primary']
secondary_url = node['hops']['url']['secondary']
Chef::Log.info "Attempting to download hadoop binaries from #{primary_url} or, alternatively, #{secondary_url}"

base_package_filename = File.basename(primary_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source primary_url
  retries 2
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0755"
  ignore_failure true
  # TODO - checksum
  action :create_if_missing
end

base_package_filename = File.basename(secondary_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source secondary_url
  retries 2
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0755"
  # TODO - checksum
  action :create_if_missing
  not_if { ::File.exist?(cached_package_filename) }
end

hin = "#{node['hops']['home']}/.#{base_package_filename}_installed"
base_name = File.basename(base_package_filename, ".tgz")
# Extract and install hadoop
bash 'extract-hadoop' do
  user "root"
  code <<-EOH
        set -e
	      tar -zxf #{cached_package_filename} -C #{node['hops']['dir']}
        # remove the config files that we would otherwise overwrite
        rm -rf #{node['hops']['home']}/etc/*

        # Force copy the old etc/hadoop files to our new installation, if there are any
        # at this stage base_dir is still pointing to the old installation
        if [ -d #{node['hops']['base_dir']} ] ; then
           cp -rpf #{node['hops']['base_dir']}/etc/* #{node['hops']['home']}/etc/*
        fi
        rm -f #{node['hops']['base_dir']}
        ln -s #{node['hops']['home']} #{node['hops']['base_dir']}

        # chown -L : traverse symbolic links
        chown -RL #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{node['hops']['base_dir']}
        chmod 750 #{node['hops']['home']}

        # Write flag
        touch #{hin}
	EOH
  not_if { ::File.exist?("#{hin}") }
end

directory node['hops']['logs_dir'] do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0770"
  action :create
end

directory node['hops']['tmp_dir'] do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "1770"
  action :create
end

# For the LinuxContainerExecutor to work the path the following dirs need to be root:hadoop and not group writable
lce_dirs = [node['hops']['home'], node['hops']['conf_dir_parent'], node['hops']['conf_dir']]
for dir in lce_dirs do
  directory dir do
    owner "root"
    group node['hops']['group']
    mode "0750"
  end
end

# For the LinuxContainerExecutor to work the container-executor bin needs to be owned by root:hadoop and have permission ---sr-s--- (6150)
file "#{node['hops']['bin_dir']}/container-executor" do
  owner "root"
  group node['hops']['group']
  mode "6150"
end

if node['hops']['native_libraries'] == "true"

  hadoop_src_url = node['hops']['hadoop_src_url']
  base_hadoop_src_filename = File.basename(hadoop_src_url)
  cached_hadoop_src_filename = "#{Chef::Config['file_cache_path']}/#{base_hadoop_src_filename}"

  remote_file cached_hadoop_src_filename do
    source hadoop_src_url
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0755"
    action :create_if_missing
  end

  hadoop_src_name = File.basename(base_hadoop_src_filename, ".tar.gz")
  natives="#{node['hops']['dir']}/.downloaded_#{hadoop_src_name}"

  bash 'build-hadoop-from-src-with-native-libraries' do
    user node['hops']['hdfs']['user']
    code <<-EOH
        set -e
        cd #{Chef::Config['file_cache_path']}
	      tar -xf #{cached_hadoop_src_filename}
        cd #{hadoop_src_name}
        mvn package -Pdist,native -DskipTests -Dtar
        cp -r hadoop-dist/target/hadoop-#{node['hops']['version']}/lib/native/* #{node['hops']['home']}/lib/native/
        chown -R #{node['hops']['hdfs']['user']} #{node['hops']['home']}/lib/native/
        touch #{natives}
	EOH
    not_if { ::File.exist?("#{natives}") }
  end
end

magic_shell_environment 'PATH' do
  value "$PATH:#{node['hops']['base_dir']}/bin"
end

magic_shell_environment 'JAVA_HOME' do
  value "#{node['java']['java_home']}"
end

magic_shell_environment 'HADOOP_HOME' do
  value node['hops']['base_dir']
end

magic_shell_environment 'HADOOP_CONF_DIR' do
  value "#{node['hops']['base_dir']}/etc/hadoop"
end

magic_shell_environment 'HADOOP_PID_DIR' do
  value "#{node['hops']['base_dir']}/logs"
end

magic_shell_environment 'HADOOP_PID_DIR' do
  value "#{node['hops']['base_dir']}/logs"
end


Chef::Log.info "Number of gpus set was: #{node['hops']['yarn']['gpus']}"

if "#{node['hops']['yarn']['gpus']}".eql?("*")

  bash 'count_num_gpus' do
  user "root"
  code <<-EOH
    nvidia-smi -L | wc -l > /tmp/num_gpus
    if [ ! -f /tmp/num_gpus ] ; then
      echo "0" > /tmp/num_gpus
    fi
    chmod +r /tmp/num_gpus
  EOH
  end
end

rm_private_ip = private_recipe_ip("hops","rm")

begin
  jhs_private_ip = private_recipe_ip("hops","jhs")
rescue
  jhs_private_ip = ""
  Chef::Log.warn "could not find the joh history server IP - maybe it is not installed."
end

# This is here because Pydoop consults mapred-site.xml
# Pydoop is a dependancy of hdfscontents which is installed
# in hopsworks-chef::default
template "#{node['hops']['conf_dir']}/mapred-site.xml" do
  source "mapred-site.xml.erb"
  owner node['hops']['mr']['user']
  group node['hops']['group']
  mode "750"
  variables({
      :rm_private_ip => rm_private_ip,
      :jhs_private_ip => jhs_private_ip
  })
  action :create
end

template "/etc/ld.so.conf.d/hops.conf" do
  source "hops.conf.erb"
  owner "root"
  group "root"
  mode "644"
  action :create
end


bash "ldconfig" do
  user "root"
  code <<-EOF
     ldconfig
  EOF
end
