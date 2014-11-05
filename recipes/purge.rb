bash 'kill_running_services' do
user "root"
ignore_failure :true
code <<-EOF
  #{node[:hadoop][:home]}/sbin/stop-nn.sh
  #{node[:hadoop][:home]}/sbin/stop-dn.sh
  #{node[:hadoop][:home]}/sbin/stop-rm.sh
  #{node[:hadoop][:home]}/sbin/stop-nm.sh
EOF
end

directory node[:hadoop][:dir] do
  recursive true
  action :delete
  ignore_failure :true
end
