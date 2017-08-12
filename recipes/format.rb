include_recipe "hops::default" 


for script in node.hops.nn.scripts
  template "#{node.hops.home}/sbin/#{script}" do
    source "#{script}.erb"
    owner node.hops.hdfs.user
    group node.hops.group
    mode 0775
  end
end 


Chef::Log.info "NameNode format option: #{node.hops.nn.format_options}"

template "#{node.hops.home}/sbin/format-nn.sh" do
  source "format-nn.sh.erb"
  owner node.hops.hdfs.user
  group node.hops.group
  mode 0775
  variables({
            :format_opts => node.hops.nn.format_options
        })
end



# it is ok if all namenodes format the fs. Unless you add a new one later..
# if the nn has already been formatted, re-formatting it returns error
# TODO: test if the NameNode is running
if ::File.exist?("#{node.hops.home}/.nn_formatted") === false || "#{node.hops.reformat}" === "true"
   hops_start "format-nn" do
     action :format_nn
   end   
else 
  Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node.hops.nn.name_dir}/current) and set node.hops.reformat to true"
end


#
# validation that formatting worked correctly.
#
begin
    exec=node['ndb']['scripts_dir'] + "/mysql-client.sh"    
    bash "validate_formatting" do
     user "root"
     code <<-EOF
       #{exec} hops -e "select count(*) from hfds_variables" | grep 4
    EOF
  end
rescue
  raise "Formatting the NameNode failed for some reason."
end
