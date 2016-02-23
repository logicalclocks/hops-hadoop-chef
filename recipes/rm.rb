include_recipe "hops::wrap"
include_recipe "hadoop::rm"


ndb_connectstring()

template "#{node[:hadoop][:home]}/etc/hadoop/RM_EventAPIConfig.ini" do 
  source "RM_EventAPIConfig.ini.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connectstring]
            })
end

template "#{node[:hadoop][:home]}/etc/hadoop/RT_EventAPIConfig.ini" do 
  source "RT_EventAPIConfig.ini.erb"
  owner node[:hdfs][:user]
  group node[:hadoop][:group]
  mode "755"
  variables({
              :ndb_connectstring => node[:ndb][:connectstring]
            })
end



