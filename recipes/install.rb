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


if node['hops']['os_defaults'] == "true" then

  # http://blog.cloudera.com/blog/2015/01/how-to-deploy-apache-hadoop-clusters-like-a-boss/

  # case node['platform']
  # when "ubuntu"
  #   node.default['sysctl']['conf_file'] = "/etc/sysctl.d/99-chef-hops.conf"
  # when "rhel"
  #   node.default['sysctl']['conf_file'] = "/etc/sysctl.d/99-chef-hops.conf"
  # end


  # node.default['sysctl']['allow_sysctl_conf'] = true
  # node.default['sysctl']['params']['vm']['swappiness'] = 1
  # node.default['sysctl']['params']['vm']['overcommit_memory'] = 1
  # node.default['sysctl']['params']['vm']['overcommit_ratio'] = 100
  # node.default['sysctl']['params']['net']['core']['somaxconn'] = 1024
  # include_recipe 'sysctl::apply'

  #
  # http://www.slideshare.net/vgogate/hadoop-configuration-performance-tuning
  #
  case node['platform_family']
  when "debian"
    bash "configure_os" do
      user "root"
      code <<-EOF
   EOF
    end
  when "redhat"
    bash "configure_os" do
      user "root"
      code <<-EOF
      echo "never" > /sys/kernel/mm/redhat_transparent_hugepages/defrag
     EOF
    end

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
  home "/home/#{node['hops']['yarnapp']['user'] }"
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
    package "g++" do
      options "--force-yes"
    end
    package "autoconf" do
      options "--force-yes"
    end
    package "automake" do
      options "--force-yes"
    end
    package "libtool" do
      options "--force-yes"
    end
    package "zlib1g-dev" do
      options "--force-yes"
    end
    package "libssl-dev" do
      options "--force-yes"
    end
    package "pkg-config" do
      options "--force-yes"
    end
    package "maven" do
      options "--force-yes"
    end

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
#    bash 'install-maven' do
#       user "root"
#       code <<-EOH
#         set -e
#        sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
#        sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
#         sudo yum install -y apache-maven
# 	EOH
#      not_if { ::File.exist?("/etc/yum.repos.d/epel-apache-maven.repo") }
#     end


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

directory node['hops']['dir'] do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0775"
  action :create
  not_if { File.directory?("#{node['hops']['dir']}") }
end

directory node['hops']['data_dir'] do
  owner node['hops']['hdfs']['user']
  group node['hops']['group']
  mode "0770"
  recursive true
  action :create
end

if "#{node['hops']['dn']['data_dir']}".include? ","
  dirs = node['hops']['dn']['data_dir'].split(",")
  for d in dirs do
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
  directory node['hops']['dn']['data_dir'] do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0770"
    recursive true
    action :create
  end
end

directory node['hops']['nn']['name_dir'] do
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
        rm -f #{node['hops']['home']}/etc/hadoop/yarn-site.xml
        rm -f #{node['hops']['home']}/etc/hadoop/container-executor.cfg
        rm -f #{node['hops']['home']}/etc/hadoop/core-site.xml
        rm -f #{node['hops']['home']}/etc/hadoop/hdfs-site.xml
        rm -f #{node['hops']['home']}/etc/hadoop/mapred-site.xml
        rm -f #{node['hops']['home']}/etc/hadoop/log4j.properties

        # Force copy the old etc/hadoop files to our new installation, if there are any
        if [ -d #{node['hops']['base_dir']} ] ; then
           cp -rpf #{node['hops']['base_dir']}/etc/hadoop/* #{node['hops']['home']}/etc/hadoop
        fi
        rm -f #{node['hops']['base_dir']}
        ln -s #{node['hops']['home']} #{node['hops']['base_dir']}
        # chown -L : traverse symbolic links
        chown -RL #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{node['hops']['home']}
        chown -RL #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{node['hops']['base_dir']}
        chmod 770 #{node['hops']['home']}
        touch #{hin}
	EOH
  not_if { ::File.exist?("#{hin}") }
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


bash 'update_permissions_etc_dir' do
  user "root"
  code <<-EOH
    set -e
    chmod 775 #{node['hops']['conf_dir']}
  EOH
end

if node['hops']['cgroups'].eql? "true"

  case node['platform_family']
  when "debian"
    package "libcgroup-dev" do
    end

  when "redhat"

    # This doesnt work for rhel-7
    package "libcgroup" do
    end
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


directory "/sys/fs/cgroup/cpu/hops-yarn" do
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "0755"
  action :create
end

directory "/sys/fs/cgroup/devices/hops-yarn" do
  owner node['hops']['yarn']['user']
  group node['hops']['group']
  mode "0755"
  action :create
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
template "#{node['hops']['base_dir']}/etc/hadoop/mapred-site.xml" do
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
