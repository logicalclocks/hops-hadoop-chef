# Cookbook Name:: hadoop
# Recipe:: default
#
# Copyright 2015, KTH
#
# All rights reserved - Do Not Redistribute
#


require 'resolv'

include_recipe "hops::wrap"
include_recipe "hadoop::default"

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

set_hostnames("hops", "nn")
set_hostnames("hops", "dn")
ndb_connectstring()

jdbc_url()

nnPort=29211
my_ip = my_private_ip()
my_public_ip = my_public_ip()
rm_private_ip = private_recipe_ip("hops","rm")
rm_public_ip = public_recipe_ip("hops","rm")


firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"


allNNs = ""
for nn in private_recipe_hostnames("hops","nn")
   allNNs += "hdfs://" + "#{nn}" + ":#{nnPort},"
end
if allNNs != ""
   allNNs.chomp(",")
end

hopsworksNodes = ""
if node[:hops][:use_hopsworks].eql? "true"
  hopsworksNodes = node[:hopsworks][:default][:private_ips].join(",")
end

file "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  owner node[:hdfs][:user]
  action :delete
end

template "#{node[:hadoop][:home]}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => my_ip,
              :firstNN => firstNN,
              :hopsworks => hopsworksNodes,
              :allNNs => allNNs
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
              :myNN => my_ip,
              :firstNN => firstNN,
              :addr1 => my_ip + ":40100",
              :addr2 => my_ip + ":40101",
              :addr3 => my_ip + ":40102",
              :addr4 => my_ip + ":40103",
              :addr5 => my_ip + ":40104",
            })
end
