include_recipe "hops::wrap"
include_recipe "apache_hadoop::nm"

remote_file "#{node.hops.dir}/hadoop/share/hadoop/yarn/lib/#{node.yarn.spark.shuffle_jar}"  do
  user node.apache_hadoop.user
  group node.apache_hadoop.group
  source node.yarn.spark.shuffle_url
  mode 0644
  action :create_if_missing
end
