
hops_ndb "install" do
  action :nothing
end

hops_path = "#{Chef::Config[:file_cache_path]}/hops.sql"
template hops_path do
  source "hops.sql.erb"
  owner "root" 
  mode "0755"
  notifies :install_hops, "hops_ndb[install]", :immediately 
end

bash "copy_native_libs" do
  user node[:hdfs][:user]
  code <<-EOF
     cp -rf #{node[:mysql][:base_dir]}/lib/* #{node[:hadoop][:home]}/lib/native/
  EOF
end

include_recipe "hadoop::nn"
