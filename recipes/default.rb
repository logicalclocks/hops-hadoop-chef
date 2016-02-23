# Cookbook Name:: hadoop
# Recipe:: default
#
# Copyright 2015, Dowling
#
# All rights reserved - Do Not Redistribute
#


require 'resolv'

nnPort=node[:hadoop][:nn][:port]
my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")
rm_dest_ip = rm_private_ip

include_recipe "hops::wrap"
include_recipe "hadoop::default"

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

ndb_connectstring()

jdbc_url()

firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"
rpcNN = private_recipe_ip("hops", "nn") + ":#{nnPort}"

if node[:hops][:nn][:private_ips].length > 1 
  allNNIps = node[:hops][:nn][:private_ips].join(":#{nnPort},") + ":#{nnPort}"
else
  allNNIps = "#{node[:hops][:nn][:private_ips][0]}" + ":#{nnPort}"
end

hopsworksNodes = ""
if node[:hops][:use_hopsworks].eql? "true"
  hopsworksNodes = node[:hopsworks][:default][:private_ips].join(",")
end

file "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  owner node[:hdfs][:user]
  action :delete
end

if node[:ndb][:TransactionInactiveTimeout].to_i < node[:hadoop][:leader_check_interval_ms].to_i
 raise "The leader election protocol has a higher timeout than the transaction timeout in NDB. We can get false suspicions for a live leader. Invalid configuration."
end

template "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :firstNN => firstNN,
              :hopsworks => hopsworksNodes,
              :allNNs => allNNIps
            })
end

file "#{node[:hadoop][:home]}/etc/hadoop/hdfs-site.xml" do 
  owner node[:hdfs][:user]
  action :delete
end

template "#{node[:hadoop][:conf_dir]}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :firstNN => firstNN
            })
end

template "#{node[:hadoop][:conf_dir]}/erasure-coding-site.xml" do
  source "erasure-coding-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
end

file "#{node[:hadoop][:home]}/etc/hadoop/yarn-site.xml" do 
  owner node[:hdfs][:user]
  action :delete
end

container_executor="org.apache.hadoop.yarn.server.nodemanager.DefaultContainerExecutor"
if node[:hadoop][:cgroups].eql? "true" 
  container_executor="org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor"
end


template "#{node[:hadoop][:home]}/etc/hadoop/yarn-site.xml" do
  source "yarn-site.xml.erb"
  owner node[:hadoop][:yarn][:user]
  group node[:hadoop][:group]
  mode "666"
  variables({
              :rm_private_ip => rm_dest_ip,
              :rm_public_ip => rm_public_ip,
              :available_mem_mb => node[:hadoop][:yarn][:nm][:memory_mbs],
              :my_public_ip => my_public_ip,
              :my_private_ip => my_ip,
              :container_executor => container_executor
            })
  action :create_if_missing
end

