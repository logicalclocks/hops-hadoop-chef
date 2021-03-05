actions :update_local_cache

# paths to copy to the local cache
# [src,.....]
# dst is infered from the local cache dir 
attribute :paths, :kind_of => Array, :default => []

# hdfs paths to which we copy the local cache paths
# [dst,.....]
# src is infered from the local cache dir 
attribute :hdfs_paths, :kind_of => Array, :default => []

attribute :owner, :kind_of => String, :default => node['hops']['hdfs']['user']
attribute :group, :kind_of => String, :default => node['hops']['group']
attribute :mode, :kind_of => String, :default => "1755"

default_action :update_local_cache


