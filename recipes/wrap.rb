
node[:hops][:recipes].each do |r|
  node.default[:hadoop]["#{r}"][:private_ips] = node.default[:hops]["#{r}"][:private_ips]
  node.default[:hadoop]["#{r}"][:public_ips] = node.default[:hops]["#{r}"][:public_ips]
end
