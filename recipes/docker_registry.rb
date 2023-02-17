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
base_filename = File.basename(node['hops']['docker']['registry']['download_url'])

remote_file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  source node['hops']['docker']['registry']['download_url']
  backup false
  action :create_if_missing
end

#import load registry image
bash "import_image" do
  user "root"
  code <<-EOF
    docker load -i #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
end

#delete registry image tar
file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  action :delete
  not_if { exists_local("cloud", "default") }
end

# Here we are fixing an old mistake. We should be storing the docker images
# in a directory under the hopsworks-data directory so that it survives
# docker registry restarts.
bash "move_docker_registry_volume" do
  user "root"
  code <<-EOF
    # Make sure
    set -e
    docker stop registry

    org_registry_mount=`docker container inspect registry | jq -r '.[0].Mounts | .[] | select( .Destination == "/var/lib/registry") | .Source'`

    mv $org_registry_mount #{node['hops']['data_volume']['docker_registry']}
  EOF
  only_if "docker container inspect registry"
  not_if { Dir.exists? node['hops']['data_volume']['docker_registry'] }
end

# If the container doesn't exists yet then we should create the directory manually.
# If the directory was created before, this operations will not have any effect.
directory node['hops']['data_volume']['docker_registry'] do
  owner "root"
  group "root"
  mode "0750"
end

# To be able to reconfigure the docker registry and make this recipe
# idempotent, we should stop and remove the existing docker registry
# before starting it again in the next step
bash "stop_docker_registry" do
  user "root"
  code <<-EOF
    docker stop registry
    docker rm registry
  EOF
  only_if "docker container inspect registry"
end

# we are root, using kagent's certificate should be ok
kagent_crypto_dir = x509_helper.get_crypto_dir(node['kagent']['user'])
certificate_name = x509_helper.get_certificate_bundle_name(node['kagent']['user'])
key_name = x509_helper.get_private_key_pkcs8_name(node['kagent']['user'])
#start docker registry
bash "start_docker_registry" do
  user "root"
  code <<-EOF
    docker run -d \
              --restart=always \
              --name registry \
              -v #{kagent_crypto_dir}:/certs \
              -v #{node['hops']['data_volume']['docker_registry']}:/var/lib/registry \
              -e REGISTRY_STORAGE_DELETE_ENABLED=true \
              -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
              -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/#{certificate_name} \
              -e REGISTRY_HTTP_TLS_KEY=/certs/#{key_name} \
              -e REGISTRY_HTTP_TLS_MINIMUMTLS=tls1.2 \
              -p #{node['hops']['docker']['registry']['port']}:443 \
              registry
  EOF
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
download_command = " wget --no-check-certificate #{image_url}"

registry_address = "#{registry_host}:#{node['hops']['docker']['registry']['port']}"
base_image = "#{node['hops']['docker']['base']['image']['name']}:#{node['hops']['docker_img_version']}"
base_image_python = "#{node['hops']['docker']['base']['image']['python']['name']}:#{node['hops']['docker_img_version']}"
docker_image_experimental = "#{node['hops']['docker']['experimental']}"

if node['install']['enterprise']['install'].casecmp? "true"
  image_url ="#{node['install']['enterprise']['download_url']}/docker-tars/#{node['hops']['docker_img_version']}/#{base_filename}"
  download_command = " wget --no-check-certificate --user #{node['install']['enterprise']['username']} --password #{node['install']['enterprise']['password']} #{image_url}"
end

bash "download_images" do
  user "root"
  sensitive true
  code <<-EOF
       #{download_command} -O #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
  not_if { File.exist? "#{Chef::Config['file_cache_path']}/#{base_filename}" }
  not_if "docker image inspect #{registry_address}/#{base_image} #{registry_address}/#{base_image_python} #{registry_address}/#{docker_image_experimental}"
end

#import docker base image
bash "import_images" do
  user "root"
  code <<-EOF
    docker load -i #{Chef::Config['file_cache_path']}/#{base_filename}
  EOF
  not_if "docker image inspect #{registry_address}/#{base_image} #{registry_address}/#{base_image_python} #{registry_address}/#{docker_image_experimental}"
end

bash "tag_images" do
  user "root"
  code <<-EOF
    docker tag #{base_image} #{registry_address}/#{base_image}
    docker rmi #{base_image}
    docker tag #{base_image_python} #{registry_address}/#{base_image_python}
    docker rmi #{base_image_python}
    docker tag docker/#{docker_image_experimental} #{registry_address}/#{docker_image_experimental}
    docker rmi docker/#{docker_image_experimental}
  EOF
  not_if "docker image inspect #{registry_address}/#{base_image} #{registry_address}/#{base_image_python} #{registry_address}/#{docker_image_experimental}"
end

bash "push_images" do
  user "root"
  code <<-EOF
    docker push #{registry_address}/#{base_image}
    docker push #{registry_address}/#{base_image_python}
    docker push #{registry_address}/#{docker_image_experimental}
  EOF
end

#delete tar
file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  action :delete
  only_if { File.exist? "#{Chef::Config['file_cache_path']}/#{base_filename}" }
end

#git
git_image_url = node['hops']['docker']['git']['download_url']
git_filename = File.basename(git_image_url)
git_image = "#{node['hops']['docker']['git']['image']['name']}:#{node['hops']['docker']['git']['image']['version']}"

bash "download_git_image" do
  user "root"
  sensitive true
  code <<-EOF
    wget --no-check-certificate #{git_image_url} -O #{Chef::Config['file_cache_path']}/#{git_filename}
  EOF
  not_if { File.exist? "#{Chef::Config['file_cache_path']}/#{git_filename}" }
  not_if "docker image inspect #{registry_address}/#{git_image}"
end

bash "tag_git_images" do
  user "root"
  code <<-EOF
    docker load -i #{Chef::Config['file_cache_path']}/#{git_filename}
    docker tag #{git_image} #{registry_address}/#{git_image}
    docker rmi #{git_image}
    docker push #{registry_address}/#{git_image}
  EOF
  not_if "docker image inspect #{registry_address}/#{git_image}"
end

file "#{Chef::Config['file_cache_path']}/#{git_filename}" do
  action :delete
  only_if { File.exist? "#{Chef::Config['file_cache_path']}/#{git_filename}" }
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

if exists_local("hopsworks", "default")
  include_recipe "hops::docker_cgroup"
end
