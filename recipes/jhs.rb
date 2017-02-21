include_recipe "hops::wrap"
include_recipe "apache_hadoop::jhs"


 # Directory for RS erasure coded data
for d in %w{ /raidrs /parity }
  apache_hadoop_hdfs_directory "#{d}" do
    action :create_as_superuser
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode "1777"
    not_if ". #{node.apache_hadoop.home}/sbin/set-env.sh && #{node.apache_hadoop.home}/bin/hdfs dfs -test -d #{d}"
  end
end
