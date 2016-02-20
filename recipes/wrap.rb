
node.override[:hadoop][:version]                   = node[:hops][:version]
node.override[:hadoop][:dir]                       = node[:hops][:dir]
node.override[:hadoop][:home]                      = node[:hops][:dir] + "/hadoop-" + node[:hops][:version]
node.override[:hadoop][:base_dir]                  = node[:hops][:dir] + "/hadoop"
node.override[:hadoop][:logs_dir]                  = node[:hadoop][:home] + "/logs"
node.override[:hadoop][:tmp_dir]                   = "#{node[:hadoop][:home]}/tmp"
node.override[:hadoop][:conf_dir]                  = "#{node[:hadoop][:home]}/etc/hadoop"
node.override[:hadoop][:sbin_dir]                  = "#{node[:hadoop][:home]}/sbin"
node.override[:hadoop][:bin_dir]                   = "#{node[:hadoop][:home]}/bin"
node.override[:hadoop][:dn][:data_dir]             = "#{node[:hadoop][:data_dir]}/hdfs/dn"
node.override[:hadoop][:nn][:name_dir]             = "#{node[:hadoop][:data_dir]}/hdfs/nn"


node.override[:hadoop][:nn][:direct_memory_size]   = node[:hops][:nn][:direct_memory_size]
node.override[:hadoop][:nn][:heap_size]            = node[:hops][:nn][:heap_size]

node[:hops][:recipes].each do |r|
  node.normal[:hadoop]["#{r}"][:private_ips]       = node[:hops]["#{r}"][:private_ips]
  node.normal[:hadoop]["#{r}"][:public_ips]        = node[:hops]["#{r}"][:public_ips]
end

node.override[:hadoop][:yarn][:rt]                 = node[:hops][:yarn][:rt]

