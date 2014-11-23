actions :create, :mapred_dirs

attribute :name, :kind_of => String, :name_attribute => true
attribute :mode, :kind_of => String, :default => "0750"
attribute :owner, :kind_of => String, :default => "mapred"

default_action :create

