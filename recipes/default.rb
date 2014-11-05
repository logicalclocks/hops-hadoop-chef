#
# Cookbook Name:: hadoop
# Recipe:: default
#
# Copyright 2013, KTH
#
# All rights reserved - Do Not Redistribute
#

libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')
require 'resolv'

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

# get your ip address
my_ip = my_private_ip()

# set node[:ndb][:connect_string]
ndb_connectstring()

# set node[:ndb][:mysql][:jdbc_url]
jdbc_url()

directory node[:hadoop][:logs_dir] do
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "0755"
  action :create
end

directory node[:hadoop][:tmp_dir] do
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "0755"
  action :create
end

directory node[:hadoop][:conf_dir] do
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "0755"
  action :create
end

template "#{node[:hadoop][:conf_dir]}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :addr1 => my_ip + ":40100",
              :addr2 => my_ip + ":40101",
              :addr3 => my_ip + ":40102",
              :addr4 => my_ip + ":40103",
              :addr5 => my_ip + ":40104",
              :mysql_host => node[:ndb][:connect_string].split(":").first
            })
end

template "#{node[:hadoop][:home]}/etc/hadoop/hadoop-env.sh" do
  source "hadoop-env.sh.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "755"
end


template "#{node[:hadoop][:home]}/etc/hadoop/jmxremote.password" do 
  source "jmxremote.password.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "600"
end

template "#{node[:hadoop][:home]}/sbin/kill-process.sh" do 
  source "kill-process.sh.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "754"
end


l = node[:hadoop][:nn][:private_ips].length
last=node[:hadoop][:nn][:private_ips][l-1]
first=node[:hadoop][:nn][:private_ips][0]



if node[:hadoop][:install_protobuf]
  proto_url = node[:protobuf][:url]
  Chef::Log.info "Downloading hadoop binaries from #{proto_url}"
  proto = File.basename(proto_url)
  proto_filename = "#{Chef::Config[:file_cache_path]}/#{proto}"

  remote_file proto_filename do
    source proto_url
    owner node[:hadoop][:user]
    group node[:hadoop][:group]
    mode "0755"
    # TODO - checksum
    action :create_if_missing
  end

  bash "install_protobuf_2_5" do
    user node[:hadoop][:user]
    code <<-EOF
    apt-get -y remove protobuf-compiler
    tar -xzf #{proto_filename} -C #{Chef::Config[:file_cache_path]}
    cd #{Chef::Config[:file_cache_path]}/protobuf-2.5.0
    ./configure --prefix=/usr
    make
    make install
    protoc --version
    EOF
    not_if { "protoc --version | grep 2\.5" }
  end
end

bash "update_env_variables_for_user" do
    user node[:hadoop][:user]
    code <<-EOF
# add the environment variables when logging in using non-interactive shell (i.e., using ssh)
# .bash_profile is sourced when logging in with ssh, .bashrc is not sources

cp /home/#{node[:hadoop][:user]}/.bashrc /home/#{node[:hadoop][:user]}/.bashrc.bak

# make recipe idempotent, by cleaning out old profile
rm /home/#{node[:hadoop][:user]}/.bash_profile

echo export JAVA_HOME=#{node[:java][:java_home]} >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export HADOOP_INSTALL=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
# '' (single quoting) a string causes its variables not to be dereferenced
echo 'export PATH=\$PATH:#{node[:hadoop][:dir]}/hadoop/bin' >> /home/#{node[:hadoop][:user]}/.bash_profile
# \\ has the same effect as a single '\' on singly quoted string
echo export PATH=\\$PATH:#{node[:hadoop][:dir]}/hadoop/sbin >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export HADOOP_MAPRED_HOME=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export HADOOP_COMMON_HOME=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export HADOOP_HDFS_HOME=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export YARN_HOME=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export HADOOP_HOME=#{node[:hadoop][:dir]}/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile

echo export HADOOP_CONF_DIR=#{node[:hadoop][:dir]}/hadoop/etc/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export YARN_CONF_DIR=#{node[:hadoop][:dir]}/hadoop/etc/hadoop >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export LD_LIBRARY_PATH=#{node[:ndb][:libndb]} >> /home/#{node[:hadoop][:user]}/.bash_profile

echo export HADOOP_PID_DIR=#{node[:hadoop][:dir]}/hadoop/logs >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export YARN_PID_DIR=#{node[:hadoop][:dir]}/hadoop/logs >> /home/#{node[:hadoop][:user]}/.bash_profile

# echo export 'HADOOP_CLASSPATH=:.:\$HADOOP_HOME/share/hadoop/yarn/test/*:\$HADOOP_HOME/share/hadoop/yarn/*:\$HADOOP_HOME/share/hadoop/yarn/lib/*:\$HADOOP_HOME/share/hadoop/mapreduce/*:\$HADOOP_HOME/share/hadoop/mapreduce/lib/*:\$HADOOP_HOME/share/hadoop/mapreduce/test/*:\$HADOOP_HOME/share/hadoop/common/lib/*:\$HADOOP_HOME/share/hadoop/hdfs/lib/*:\$HADOOP_HOME/share/hadoop/tools/lib/*:\$HADOOP_HOME/share/hadoop/common/*:\$HADOOP_HOME/share/hadoop/common/*:\$HADOOP_HOME/share/hadoop/hdfs/*:\$HADOOP_HOME/share/hadoop/mapreduce/*' >> /home/#{node[:hadoop][:user]}/.bash_profile

echo export 'HADOOP_CLASSPATH=:.:\$HADOOP_CONF_DIR:\$HADOOP_COMMON_HOME/share/hadoop/common/*:\$HADOOP_COMMON_HOME/share/hadoop/common/lib/*:\$HADOOP_HDFS_HOME/share/hadoop/hdfs/*:\$HADOOP_HDFS_HOME/share/hadoop/hdfs/lib/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/lib/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/test/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/test/*:\$HADOOP_COMMON_HOME/share/hadoop/tools/lib/*' >> /home/#{node[:hadoop][:user]}/.bash_profile

 
echo export 'CLASSPATH=\$HADOOP_CLASSPATH' >> /home/#{node[:hadoop][:user]}/.bash_profile

echo "export HADOOP_NAMENODE_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8077 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{node[:hadoop][:user]}/.bash_profile

export "HADOOP_DATANODE_OPTS=\\"-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8078 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{node[:hadoop][:user]}/.bash_profile

echo "export YARN_OPTS=\\"-Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{node[:hadoop][:user]}/.bash_profile

# Command specific options appended to HADOOP_OPTS when specified
echo "export YARN_RESOURCEMANAGER_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8082 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{node[:hadoop][:user]}/.bash_profile

echo "export YARN_NODEMANAGER_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8083 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{node[:hadoop][:user]}/.bash_profile
echo export cygwin=false >> /home/#{node[:hadoop][:user]}/.bash_profile

export HADOOP_USER_CLASSPATH_FIRST=true >> /home/#{node[:hadoop][:user]}/.bash_profile

# Wipe old .bashrc, and add new .bashrc starting with running .bash_profile and then running the old .bashrc
echo "test -f /home/#{node[:hadoop][:user]}/.bash_profile && source /home/#{node[:hadoop][:user]}/.bash_profile" > /home/#{node[:hadoop][:user]}/.bashrc
cat /home/#{node[:hadoop][:user]}/.bashrc.bak >> /home/#{node[:hadoop][:user]}/.bashrc
rm /home/#{node[:hadoop][:user]}/.bashrc.bak

# Create a ssh key, needed for start-dfs.sh and start-yarn.sh
ssh-keygen -t rsa -P '' -f /home/#{node[:hadoop][:user]}/.ssh/id_rsa
cat /home/#{node[:hadoop][:user]}/.ssh/id_rsa.pub >> /home/#{node[:hadoop][:user]}/.ssh/authorized_keys
# Disable need for user confirmation when sshing to a host for the first time. 
# The alternative would be to explicitly add hosts to .ssh/known_hosts file.
echo "\nStrictHostKeyChecking no\n" >> /home/#{node[:hadoop][:user]}/.ssh/config

EOF
  not_if { ::File.exist?("/home/#{node[:hadoop][:user]}/.ssh/config") }
end


directory "/conf" do
  owner "root"
  group node[:hadoop][:group]
  mode "0755"
  recursive true
  action :create
end


template "/conf/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner node[:hadoop][:user]
  group node[:hadoop][:group]
  mode "755"
end
