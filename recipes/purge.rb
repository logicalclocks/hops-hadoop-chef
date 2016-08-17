include_recipe "apache_hadoop::purge"


link "#{node.apache_hadoop.dir}/ndb-hops" do
  action :delete
  ignore_failure true
end

directory "#{node.apache_hadoop.dir}/ndb-hops-#{node.apache_hadoop.version}-#{node.ndb.version}" do
  recursive true
  action :delete
  ignore_failure true
end

