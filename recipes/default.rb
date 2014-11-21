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


# set node[:ndb][:connect_string]
ndb_connectstring()

# set node[:ndb][:mysql][:jdbc_url]
jdbc_url()

# get your ip address
my_ip = my_private_ip()
listNNs = "hdfs://" + private_recipe_ip("hadoop", "nn") + ":29211"
firstNN = "hdfs://" + private_recipe_ip("hadoop", "nn") + ":29211"


template "#{node[:hadoop][::conf_dir]}/core-site.xml" do 
  source "core-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => firstNN,
              :listNNs => listNNs
            })
end

template "#{node[:hadoop][:conf_dir]}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => firstNN,
              :addr1 => my_ip + ":40100",
              :addr2 => my_ip + ":40101",
              :addr3 => my_ip + ":40102",
              :addr4 => my_ip + ":40103",
              :addr5 => my_ip + ":40104",
            })
end

template "#{node[:hadoop][:conf_dir]}/hadoop-env.sh" do
  source "hadoop-env.sh.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
end

template "#{node[:hadoop][:conf_dir]}/jmxremote.password" do 
  source "jmxremote.password.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "600"
end

template "#{node[:hadoop][:conf_dir]}/yarn-jmxremote.password" do 
  source "jmxremote.password.erb"
  owner node[:hadoop][:yarn][:user]
  group node[:hadoop][:group]
  mode "600"
end


template "#{node[:hadoop][:home]}/sbin/kill-process.sh" do 
  source "kill-process.sh.erb"
  owner node[:hdfs][:user]
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
    owner node[:hdfs][:user]
    group node[:hadoop][:group]
    mode "0770"
    # TODO - checksum
    action :create_if_missing
  end

  bash "install_protobuf_2_5" do
    user node[:hdfs][:user]
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



hops_user_envs node[:hdfs][:user] do
  action :update
end

hops_user_envs node[:hadoop][:yarn][:user] do
  action :update
end

hops_user_envs node[:hadoop][:mr][:user] do
  action :update
end


directory "/conf" do
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "0775"
  recursive true
  action :create
end


template "/conf/container-executor.cfg" do
  source "container-executor.cfg.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "770"
end
