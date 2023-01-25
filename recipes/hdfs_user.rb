
group node['hops']['secure_group'] do
  action :modify
  members node['hops']['hdfs']['user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

instance_id = private_recipe_ips("hops", "nn").sort.find_index(my_private_ip())
fqdn = consul_helper.get_service_fqdn("namenode")

crypto_dir = x509_helper.get_crypto_dir(node['hops']['hdfs']['user'])
kagent_hopsify "Generate x.509" do
  user node['hops']['hdfs']['user']
  crypto_directory crypto_dir
  common_name "#{instance_id}.#{fqdn}"
  action :generate_x509
  not_if { node["kagent"]["enabled"] == "false" }
end


