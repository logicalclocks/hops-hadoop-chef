node.override.apache_hadoop.version       = node.hops.version
node.override.apache_hadoop.download_url.primary  = node.hops.download_url
node.override.apache_hadoop.download_url.secondary  = node.hops.download_url
node.override.apache_hadoop.hadoop_src_url  = node.hops.hadoop_src_url

include_recipe "hops::wrap"
include_recipe "apache_hadoop::install"
include_recipe "hops"


