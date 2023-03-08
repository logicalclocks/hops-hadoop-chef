include_recipe "hops::default"
exec=node['ndb']['scripts_dir'] + "/mysql-client.sh"

bash 'Restore deleted blocks from Cloud' do
  user node['hops']['hdfs']['user']
  group node['hops']['group']
  code <<-EOH
    #{node['hops']['bin_dir']}/hdfs namenode -rollbackDeletedCloudBlocks
  EOH
  only_if { node['hops']['enable_cloud_storage'].casecmp?("true") }
  only_if { rondb_restoring_backup() }
end

# it is ok if all namenodes format the fs. Unless you add a new one later..
# if the nn has already been formatted, re-formatting it returns error
# TODO: test if the NameNode is running
if "#{node['hops']['format']}" === "true"
  if ::File.exist?("#{node['hops']['base_dir']}/.nn_formatted") === false || "#{node['hops']['reformat']}" === "true"
    hops_ndb "format-nn" do
      action :format_nn
      only_if "#{exec} hops -e 'select count(*) from hdfs_variables' | tail -n 1 | egrep '^0$'"
    end
  else
    Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node['hops']['nn']['name_dir']}/current) and set node['hops']['reformat'] to true"
  end


  #
  # validation that formatting worked correctly.
  #
  begin
    bash "validate_formatting" do
      user "root"
      code <<-EOF
       #{exec} hops -e 'select count(*) from hdfs_variables' | tail -n 1 | egrep -v "^0$"
      EOF
    end
  rescue
    raise "Formatting the NameNode failed for some reason."
  end

end
