# When upgrading from 1.3, we need to make sure that the hadoop group_id is correctly set to 1234
action :set

default_action :set

attribute :name, :kind_of => String, :required => true

attribute :group_name, :kind_of => String, :required => true 
attribute :group_id, :kind_of => String, :required => true
attribute :install_dir, :kind_of => String, :required => true