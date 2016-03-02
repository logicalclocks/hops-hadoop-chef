

include_recipe "hops::wrap"

my_ip = my_private_ip()

nnPort = node.apache_hadoop.nn.port

hopsworksNodes = ""
if node.hops.use_hopsworks.eql? "true"
  if node.hopsworks.nil? == false && node.hopsworks.default.nil? == false && node.hopsworks.default.private_ips.nil? == false
    hopsworksNodes = node.hopsworks.default.private_ips.join(",")
  end
end

if node.hops.nn.private_ips.length > 1 
  allNNs = node.hops.nn.private_ips.join(":#{nnPort},") + ":#{nnPort}"
else
  allNNs = "#{node.hops.nn.private_ips[0]}" + ":#{nnPort}"
end


file "#{node.apache_hadoop.home}/etc/hadoop/core-site.xml" do 
  owner node.apache_hadoop.hdfs.user
  action :delete
end

myNN = "#{my_ip}:#{nnPort}"
template "#{node.apache_hadoop.home}/etc/hadoop/core-site.xml" do 
  source "core-site.xml.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  variables({
              :firstNN => "hdfs://" + myNN,
              :hopsworks => hopsworksNodes,
              :allNNs => myNN
            })
end

cache = "true"
if node.hops.nn.cache.eql? "false"
   cache = "false"
end

partition_key = "true"
if node.hops.nn.partition_key.eql? "false"
   partition_key = "false"
end


file "#{node.apache_hadoop.home}/etc/hadoop/hdfs-site.xml" do 
  owner node.apache_hadoop.hdfs.user
  action :delete
end

template "#{node.apache_hadoop.conf_dir}/hdfs-site.xml" do
  source "hdfs-site.xml.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "755"
  variables({
              :firstNN => myNN,
              :cache => cache,
              :partition_key => partition_key
            })
end

template "#{node.apache_hadoop.home}/sbin/root-drop-and-recreate-hops-db.sh" do
  source "root-drop-and-recreate-hops-db.sh.erb"
  owner "root"
  mode "700"
end


template "#{node.apache_hadoop.home}/sbin/drop-and-recreate-hops-db.sh" do
  source "drop-and-recreate-hops-db.sh.erb"
  owner node.apache_hadoop.hdfs.user
  group node.apache_hadoop.group
  mode "771"
end

include_recipe "apache_hadoop::nn"
