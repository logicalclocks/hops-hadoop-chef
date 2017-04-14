actions :systemd_reload, :start_if_not_running, :format_nn
attribute :name, :kind_of => String, :name_attribute => true

default_action :start_if_not_running
