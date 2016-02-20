node.override[:hadoop][:version]       = node[:hops][:version]
node.override[:hadoop][:download_url][:primary]  = node[:hops][:download_url]
node.override[:hadoop][:download_url][:secondary]  = node[:hops][:download_url]
node.override[:hadoop][:hadoop_src_url]  = node[:hops][:hadoop_src_url]

include_recipe "hops::wrap"
include_recipe "hadoop::install"
include_recipe "hops"


