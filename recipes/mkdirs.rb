node.normal[:mr][:dirs]      = [node[:mr][:staging_dir], node[:mr][:tmp_dir], node[:hs][:inter_dir], node[:hs][:done_dir]]

for d in node[:mr][:dirs]
  Chef::Log.info "One Creating hdfs directory: #{d}"
  hops_hdfs_directory d do
   action :create
   mode "0755"
  end
end

bash 'restart-nn' do
  user node[:hdfs][:user]
  code <<-EOH
 		#{node[:hadoop][:home]}/sbin/restart-nn.sh
 	EOH
end
