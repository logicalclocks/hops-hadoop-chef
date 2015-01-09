# Cookbook Name:: hadoop
# Recipe:: default
#
# Copyright 2013, KTH
#
# All rights reserved - Do Not Redistribute
#

include_recipe "hadoop::default"

libpath = File.expand_path '../../../kagent/libraries', __FILE__
require File.join(libpath, 'inifile')
require 'resolv'

# Convert all private_ips to their hostnames
# Hadoop requires fqdns to work - won't work with IPs
hostf = Resolv::Hosts.new

set_hostnames("hops", "nn")
set_hostnames("hops", "dn")
ndb_connectstring()

jdbc_url()

nnPort=29211
my_ip = my_private_ip()
firstNN = "hdfs://" + private_recipe_ip("hops", "nn") + ":#{nnPort}"


allNNs = ""
for nn in private_recipe_hostnames("hops","nn")
   allNNs += "hdfs://" + "#{nn}" + ":#{nnPort},"
end
#firstNN = allNNs.eql?("") ? "" : allNNs.split(",").first

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
              :myNN => firstNN,
              :allNNs => allNNs
            })
end

file "#{node[:hadoop][:home]}/etc/hadoop/hdfs-site.xml" do 
  owner node[:hdfs][:user]
  action :delete
end

mysql_host = "jdbc:mysql://localhost:#{node[:ndb][:mysql_port]}/"
template "#{node[:hadoop][:conf_dir]}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :myNN => firstNN,
              :mysql_host => node[:ndb][:connect_string].split(":").first,
              :addr1 => my_ip + ":40100",
              :addr2 => my_ip + ":40101",
              :addr3 => my_ip + ":40102",
              :addr4 => my_ip + ":40103",
              :addr5 => my_ip + ":40104",
            })
end

template "#{node[:hadoop][:home]}/etc/hadoop/ndb.props" do
  source "ndb.props.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connect_string],
              :mysql_host => "localhost", 
            })
end
