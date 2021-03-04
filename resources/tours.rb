actions :update_local_cache

# [path1, path2,....]
attribute :rel_paths, :kind_of => Array, :default => []
# [[src, dst],....]
attribute :abs_paths, :kind_of => Array, :default => []

#[[dst,user,group,mode],...]
attribute :rel_tours_info, :kind_of => Array, :default => []
#[[src,dst,user,group,mode],...]
attribute :abs_tours_info, :kind_of => Array, :default => []

default_action :update_local_cache


