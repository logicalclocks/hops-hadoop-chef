# if tls is enabled, setup dev settings by default.

if node['hops']['tls']['prod'].eql?("true")
  node.override['hops']['tls']['crl_fetcher_class'] = "org.apache.hadoop.security.ssl.RemoteCRLFetcher"
  node.override['hops']['tls']['crl_fetcher_interval'] = "1d"
  node.override['hops']['rmappsecurity']['actor_class'] = "org.apache.hadoop.yarn.server.resourcemanager.security.HopsworksRMAppSecurityActions"
  node.override['hops']['fs-security-actions']['actor_class'] = "io.hops.common.security.HopsworksFsSecurityActions"
end


if node.attribute?(:cuda) and node["cuda"].attribute?(:accept_nvidia_download_terms) 
  if node['cuda']['accept_nvidia_download_terms'].casecmp?("true")
    node.override['hops']['capacity']['resource_calculator_class'] = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"    
  end
end

# Override install binaries for enterprise edition
if node['install']['enterprise']['install'].casecmp? "true"
  node.override['hops']['dist_url']    = "#{node['install']['enterprise']['download_url']}/hopshadoop/hops-#{node['hops']['version']}.tgz"
  node.override['hops']['schema_dir']  = "#{node['install']['enterprise']['download_url']}/hopshadoop/hops-schemas"
  node.override['dal']['download_url'] = "#{node['install']['enterprise']['download_url']}/hopshadoop/ndb-dal-#{node['hops']['version']}-#{node['ndb']['version']}.jar"
end
