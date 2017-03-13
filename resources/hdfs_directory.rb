actions :create, :put, :create_as_superuser, :put_as_superuser

attribute :name, :kind_of => String, :name_attribute => true
attribute :mode, :kind_of => String, :default => ""
attribute :owner, :kind_of => String, :default => ""
attribute :group, :kind_of => String, :default => ""
attribute :dest, :kind_of => String, :default => ""
attribute :recursive, :kind_of => [TrueClass, FalseClass], :default => true 

default_action :create
