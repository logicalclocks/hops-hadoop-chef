actions :systemd_reload, :start_if_not_running, :format_nn, :zkfc, :standby, :jn

attribute :name, :kind_of => String, :name_attribute => true
attribute :ha_enabled, :equal_to => [true, false, 'true', 'false'], :default => false

default_action :start_if_not_running
