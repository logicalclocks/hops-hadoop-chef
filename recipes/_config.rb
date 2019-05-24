# if tls is enabled, setup dev settings by default.

if node['hops']['tls']['prod'].eql?("true")
  node.override['hops']['tls']['crl_fetcher_class'] = "org.apache.hadoop.security.ssl.RemoteCRLFetcher"
  node.override['hops']['tls']['crl_fetcher_interval'] = "1d"
  node.override['hops']['tls']['rmappsecurity']['actor_class'] = "org.apache.hadoop.yarn.server.resourcemanager.security.HopsworksRMAppSecurityActions"
end
