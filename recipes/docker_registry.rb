Chef::Recipe.send(:include, Hops::Helpers)

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

#download registry image
image_url = node['hops']['docker']['registry']['download_url']
base_filename = File.basename(image_url)

remote_file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  source image_url
  backup false
  action :create_if_missing
  not_if "docker image inspect registry"
end

#import load registry image
bash "import_image" do
  user "root"
  code <<-EOF
    docker load -i #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
  not_if "docker image inspect registry"
end

#delete registry image tar
file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  action :delete
  only_if { File.exist? "#{Chef::Config['file_cache_path']}/#{base_filename}" }
end

# we are root, using kagent's certificate should be ok
kagent_crypto_dir = x509_helper.get_crypto_dir(node['kagent']['user'])
certificate_name = x509_helper.get_certificate_bundle_name(node['kagent']['user'])
key_name = x509_helper.get_private_key_pkcs8_name(node['kagent']['user'])
#start docker registry
bash "start_docker_registry" do
  user "root"
  code <<-EOF
   docker run -d --restart=always --name registry -v #{kagent_crypto_dir}:/certs -e REGISTRY_STORAGE_DELETE_ENABLED=true -e REGISTRY_HTTP_ADDR=0.0.0.0:443 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/#{certificate_name} -e REGISTRY_HTTP_TLS_KEY=/certs/#{key_name} -p #{node['hops']['docker']['registry']['port']}:443 registry
   EOF
  not_if "docker container inspect registry"
end

consul_crypto_dir = x509_helper.get_crypto_dir(node['consul']['user'])
if service_discovery_enabled()
  #Register registry with Consul
  template "#{node['hops']['bin_dir']}/consul/registry-health.sh" do
    source "consul/registry-health.sh.erb"
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode 0750
    variables({
               :key => "#{consul_crypto_dir}/#{x509_helper.get_private_key_pkcs8_name(node['consul']['user'])}",
               :certificate => "#{consul_crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['consul']['user'])}",
              })
  end

  consul_service "Registering Registry with Consul" do
    service_definition "consul/registry-consul.hcl.erb"
    action :register
  end

  registry_host=consul_helper.get_service_fqdn("registry")
end

#download base env
image_url = node['hops']['docker']['base']['download_url']
base_filename = File.basename(image_url)
download_command = " wget #{image_url}"

if node['install']['enterprise']['install'].casecmp? "true"
  image_url ="#{node['install']['enterprise']['download_url']}/docker-tars/#{node['hops']['docker_img_version']}/#{base_filename}"
  download_command = " wget --user #{node['install']['enterprise']['username']} --password #{node['install']['enterprise']['password']} #{image_url}"
end

bash "download_image" do
  user "root"
  sensitive true
  code <<-EOF
       #{download_command} -O #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
  not_if { File.exist? "#{Chef::Config['file_cache_path']}/#{base_filename}" }
  not_if "docker image inspect #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}"
end

#import docker image
bash "import_image" do
  user "root"
  code <<-EOF
    docker load -i #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
  not_if "docker image inspect #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}"
end

#tag image
bash "tag_image" do
  user "root"
  code <<-EOF
    docker tag #{node['hops']['docker']['base']['name']} #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}
  EOF
  not_if "docker image inspect #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}"
end

#push image to registry
bash "push_image" do
  user "root"
  code <<-EOF
    docker push #{registry_host}:#{node['hops']['docker']['registry']['port']}/#{node['hops']['docker']['base']['name']}:#{node['install']['version']}
  EOF
end

#delete tar
file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  action :delete
  only_if { File.exist? "#{Chef::Config['file_cache_path']}/#{base_filename}" }
end

# We add docker in kagent in this recipe as the hops::docker recipe runs during the install phase and it might run
# before kagent::install
service_name='docker'
if node['kagent']['enabled'] == "true"
  kagent_config service_name do
    service "docker"
  end
end

if conda_helpers.is_upgrade
  kagent_config service_name do
    action :systemd_reload
  end
end