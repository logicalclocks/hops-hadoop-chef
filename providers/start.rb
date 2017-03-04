action :start_if_not_running do
  bash "start-if-not-running-#{new_resource.name}" do
    user "root"
    code <<-EOH
     set -e
  #  service status returns '0' even if the service is not running ;(
  #   if [ `service #{new_resource.name} status` -ne 0 ] ; then
         service #{new_resource.name} restart
 #    fi 
    EOH
  end
end

action :systemd_reload do
  bash "start-if-not-running-#{new_resource.name}" do
    user "root"
    code <<-EOH
     set -e
     systemctl daemon-reload
    EOH
  end
end



action :format_nn do

  formatMarker="#{node.hops.home}/.nn_formatted"
  if "#{node.hops.reformat}" === "true"
    ::File.delete(formatMarker)
  end
  
    bash 'format-nn' do
      user node.hops.hdfs.user
      group node.hops.group
      code <<-EOH
        set -e
        #{node.hops.base_dir}/sbin/format-nn.sh
        touch #{formatMarker}
 	EOH
      not_if {::File.exist?(formatMarker)}
    end
end

