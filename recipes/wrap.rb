
node.override.apache_hadoop.version                   = node.hops.version
node.override.apache_hadoop.dir                       = node.hops.dir
node.override.apache_hadoop.home                      = node.hops.dir + "/hadoop-" + node.hops.version
node.override.apache_hadoop.base_dir                  = node.hops.dir + "/hadoop"
node.override.apache_hadoop.logs_dir                  = node.apache_hadoop.home + "/logs"
node.override.apache_hadoop.tmp_dir                   = "#{node.apache_hadoop.home}/tmp"
node.override.apache_hadoop.conf_dir                  = "#{node.apache_hadoop.home}/etc/hadoop"
node.override.apache_hadoop.sbin_dir                  = "#{node.apache_hadoop.home}/sbin"
node.override.apache_hadoop.bin_dir                   = "#{node.apache_hadoop.home}/bin"
node.override.apache_hadoop.dn.data_dir               = "#{node.apache_hadoop.data_dir}/hdfs/dn"
node.override.apache_hadoop.nn.name_dir               = "#{node.apache_hadoop.data_dir}/hdfs/nn"
node.override.apache_hadoop.use_systemd               = node.hops.use_systemd

node.override.apache_hadoop.nn.format_options         = node.hops.nn.format_options

node.override.apache_hadoop.yarn.aux_services         = "spark_shuffle,mapreduce_shuffle"

node.override.apache_hadoop.nn.direct_memory_size   = node.hops.nn.direct_memory_size
node.override.apache_hadoop.nn.heap_size            = node.hops.nn.heap_size

node.hops.recipes.each do |r|
  node.override.apache_hadoop["#{r}"][:private_ips]       = node.hops["#{r}"][:private_ips]
  node.override.apache_hadoop["#{r}"][:public_ips]        = node.hops["#{r}"][:public_ips]
end

case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.apache_hadoop.systemd = "false"
 end
end
