node.override.apache_hadoop.version       = node.hops.version
node.override.apache_hadoop.download_url.primary  = node.hops.download_url
node.override.apache_hadoop.download_url.secondary  = node.hops.download_url
node.override.apache_hadoop.hadoop_src_url  = node.hops.hadoop_src_url

include_recipe "hops::wrap"
include_recipe "apache_hadoop::install"
include_recipe "hops"


if node.vagrant === "true" || node.vagrant == true
  # count = 0
  # for nn in node.apache_hadoop.nn['private_ips']
  #   case node.platform_family
  #   when "debian"
  #     hostsfile_entry nn do
  #       hostname  "data#{count}"
  #       action    :create
  #       unique    true
  #     end
  #   when "rhel"
  #     hostsfile_entry "#{nn}" do
  #       hostname  "data#{count}"
  #       unique    true
  #     end
  #   end
  #   count += 1
  # end

end

magic_shell_environment 'LD_LIBRARY_PATH' do
  value "#{node.hops.base_dir}/lib/libnative:$LD_LIBRARY_PATH"
end
