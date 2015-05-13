
node[:hops][:recipes].each do |r|
  node.normal[:hadoop]["#{r}"][:private_ips] = node[:hops]["#{r}"][:private_ips]
  node.normal[:hadoop]["#{r}"][:public_ips] = node[:hops]["#{r}"][:public_ips]
end
