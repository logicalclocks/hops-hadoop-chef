begin
  registry_ip = private_recipe_ip("hops","docker_registry")
  registry_host = resolve_hostname(registry_ip)
rescue
  registry_host = "localhost"
  Chef::Log.warn "could not find the docker registry ip!"
end

#for docker to push and pull from the registry it needs to trust hops_ca.pem
case node['platform_family']
when 'rhel'
  cert_target = "/etc/pki/ca-trust/source/anchors/#{registry_host}.crt"
  update_command = "update-ca-trust"
when 'debian'
  cert_target = "/usr/local/share/ca-certificates/#{registry_host}.crt"
  update_command = "update-ca-certificates"
end

# we are root, using kagent's certificate should be ok
kagent_crypto_dir = x509_helper.get_crypto_dir(node['kagent']['user'])
hops_ca = "#{kagent_crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['kagent']['user'])}"
if ::File.exist?("#{cert_target}") === false && "#{registry_host}" != "local"
  bash 'add_trust_cert' do
    user "root"
    code <<-EOH
         ln -s #{hops_ca} #{cert_target}
         #{update_command}
         EOH
  end

  #restart docker to take in account the new trusted certs
  service 'docker' do
    action [:restart]
  end
end

if service_discovery_enabled()
  registry_host=consul_helper.get_service_fqdn("registry")
end

bash "pull_image" do
  user "root"
  code <<-EOF
    docker pull #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}
  EOF
  not_if "docker image inspect #{node['hops']['docker']['base']['name']}:#{node['install']['version']}"
end
