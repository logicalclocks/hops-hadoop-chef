# if tls is enabled, setup dev settings by default.
Chef::Recipe.send(:include, Hops::Helpers)

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
  version = get_hops_version
  node.override['hops']['dist_url']    = "#{node['install']['enterprise']['download_url']}/hopshadoop/hops-#{version}.tgz"
  node.override['hops']['schema_dir']  = "#{node['install']['enterprise']['download_url']}/hopshadoop/hops-schemas"
  node.override['dal']['download_url'] = "#{node['install']['enterprise']['download_url']}/hopshadoop/ndb-dal-#{version}-#{node['ndb']['version']}.jar"
  node.override['hops']['home']        = node['hops']['dir'] + "/hadoop-" + version
  node.override['dal']['lib_url']      = "#{node['hops']['root_url']}/libhopsyarn-#{version}-#{node['ndb']['version']}.so"
  node.override['nvidia']['download_url'] = "#{node['hops']['root_url']}/nvidia-management-#{version}-#{node['ndb']['version']}.jar"
  node.override['hops']['libnvml_url']    = "#{node['hops']['root_url']}/libhopsnvml-#{version}.so"
  node.override['amd']['download_url']    = "#{node['hops']['root_url']}/amd-management-#{version}-#{node['ndb']['version']}.jar"
  node.override['hops']['librocm_url']    = "#{node['hops']['root_url']}/libhopsrocm-#{version}.so"
  node.override['hops']['yarn']['app_classpath'] = node['hops']['yarn']['app_classpath'].gsub(node['hops']['version'], version)
  node.override['hops']['version'] = version
  versions=node['hops']['versions']
  versions_arr=versions.split("2.8.2.9")
  versions=versions_arr[0] + "2.8.2.9,2.8.2.9.1"
  if versions_arr.size > 1
    versions=versions + versions_arr[1]
  end
  node.override['hops']['versions'] = versions
end

if node['hops']['rm']['private_ips'].size() > 1
  node.override['hops']['yarn']['resourcemanager_ha_enabled'] = "true"
  node.override['hops']['yarn']['resourcemanager_auto_failover_enabled'] = "true"
end
