
node.override[:hadoop][:version]                   = node[:hops][:version]
node.override[:hadoop][:dir]                       = node[:hops][:dir]

node.override[:hadoop][:nn][:direct_memory_size]   = node[:hops][:nn][:direct_memory_size]
node.override[:hadoop][:nn][:heap_size]            = node[:hops][:nn][:heap_size]

node[:hops][:recipes].each do |r|
  node.normal[:hadoop]["#{r}"][:private_ips]       = node[:hops]["#{r}"][:private_ips]
  node.normal[:hadoop]["#{r}"][:public_ips]        = node[:hops]["#{r}"][:public_ips]
end

node.override[:hadoop][:yarn][:rt]                 = node[:hops][:yarn][:rt]
