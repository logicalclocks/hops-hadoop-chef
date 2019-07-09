# if tls is enabled, setup dev settings by default.

if node['hops']['tls']['prod'].eql?("true")
  node.override['hops']['tls']['crl_fetcher_class'] = "org.apache.hadoop.security.ssl.RemoteCRLFetcher"
  node.override['hops']['tls']['crl_fetcher_interval'] = "1d"
  node.override['hops']['tls']['rmappsecurity']['actor_class'] = "org.apache.hadoop.yarn.server.resourcemanager.security.HopsworksRMAppSecurityActions"
end


if node.attribute?(:cuda) and node["cuda"].attribute?(:accept_nvidia_download_terms)
  if ['cuda']['accept_nvidia_download_terms'].casecmp("true") == 0
    node.override['hops']['capacity']['resource_calculator_class'] = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculatorGPU"    
  end
end
