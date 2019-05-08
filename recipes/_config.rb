# if tls is enabled, setup dev settings by default.

if node['hops']['tls']['dev'].eql?("true")
  node.override['hops']['tls']['crl_fetcher_class'] = "org.apache.hadoop.security.ssl.DevRemoteCRLFetcher"
  node.override['hops']['tls']['crl_fetcher_interval'] = "5m"
  node.override['hops']['tls']['rmappsecurity']['actor_class'] = "org.apache.hadoop.yarn.server.resourcemanager.security.DevHopsworksRMAppSecurityActions"
end
