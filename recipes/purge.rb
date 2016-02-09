include_recipe "hadoop::purge"



link "#{node[:hadoop][:dir]}/ndb-hops" do
  action :delete
  ignore_failure true
end

directory "#{node[:hadoop][:dir]}/ndb-hops-#{node[:hadoop][:version]}-#{node[:ndb][:version]}" do
  recursive true
  action :delete
  ignore_failure true
end

