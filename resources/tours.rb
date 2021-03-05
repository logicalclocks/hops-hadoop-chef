actions :update_local_cache

# [src,.....]
# dst is infered from the local cache dir 
attribute :rel_paths, :kind_of => Array, :default => []
# [[src, dst],....]
attribute :abs_paths, :kind_of => Array, :default => []

# [dst,.....]
# src is infered from the local cache dir 
attribute :rel_tours_info, :kind_of => Array, :default => []
#[[src,dst],...]
attribute :abs_tours_info, :kind_of => Array, :default => []

attribute :owner, :kind_of => String, :default => node['hops']['hdfs']['user']
attribute :group, :kind_of => String, :default => node['hops']['group']
attribute :mode, :kind_of => String, :default => "1755"

default_action :update_local_cache


