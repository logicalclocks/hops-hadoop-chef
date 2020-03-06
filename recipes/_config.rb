# if tls is enabled, setup dev settings by default.

if node['hops']['tls']['prod'].eql?("true")
  node.override['hops']['tls']['crl_fetcher_class'] = "org.apache.hadoop.security.ssl.RemoteCRLFetcher"
  node.override['hops']['tls']['crl_fetcher_interval'] = "1d"
  node.override['hops']['rmappsecurity']['actor_class'] = "org.apache.hadoop.yarn.server.resourcemanager.security.HopsworksRMAppSecurityActions"
  node.override['hops']['fs-security-actions']['actor_class'] = "io.hops.common.security.HopsworksFsSecurityActions"
end


if node.attribute?(:cuda) and node["cuda"].attribute?(:accept_nvidia_download_terms) 
  if node['cuda']['accept_nvidia_download_terms'].casecmp?("true")
    node.override['hops']['capacity']['resource_calculator_class'] = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculatorGPU"    
  end
end
