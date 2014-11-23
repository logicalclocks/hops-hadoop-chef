node.default[:hadoop][:download_url] = node[:hops][:download_url]
node.default[:hadoop][:hadoop_src_url] = node[:hops][:hadoop_src_url]

include_recipe "hadoop::install"
include_recipe "hops"


