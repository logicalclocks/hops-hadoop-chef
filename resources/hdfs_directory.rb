actions :create, :put, :create_as_superuser, :put_as_superuser, :rm_as_superuser, :replace_as_superuser

attribute :name, :kind_of => String, :name_attribute => true
attribute :mode, :kind_of => String, :default => ""
attribute :owner, :kind_of => String, :default => ""
attribute :group, :kind_of => String, :default => ""
attribute :dest, :kind_of => String, :default => ""
attribute :recursive, :kind_of => [TrueClass, FalseClass], :default => true
attribute :isDir, :kind_of => [TrueClass, FalseClass], :default => false

default_action :create

