available_memory_in_host_bytes = (node['memory']['total'].gsub("kB","").to_i/10241024) * 1073741824
docker_default_hard_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['hard-limit-default'].gsub("GB", "").to_i) * 1073741824
docker_default_soft_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['soft-limit-default'].gsub("GB", "").to_i) * 1073741824
docker_hard_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['hard-limit'].gsub("GB", "").to_i) * 1073741824
docker_soft_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['soft-limit'].gsub("GB", "").to_i) * 1073741824
# dynamic memory allocation
available_memory_in_host_bytes = available_memory_in_host_bytes - docker_hard_limit_memory_bytes
# assumption: Hopsworks services require 30GB
excess_memory = available_memory_in_host_bytes - (30 * 1073741824)
if excess_memory < 0 || (docker_default_hard_limit_memory_bytes != docker_hard_limit_memory_bytes || docker_default_soft_limit_memory_bytes != docker_soft_limit_memory_bytes)
  excess_memory = 0
end
excess_memory = (excess_memory/4).round()

node.override['hops']['docker']['cgroup']['memory']['hard-limit'] = ((docker_hard_limit_memory_bytes + excess_memory)/1073741824).to_s + "GB"
node.override['hops']['docker']['cgroup']['memory']['soft-limit'] = ((docker_soft_limit_memory_bytes + excess_memory) /1073741824).to_s + "GB"


if node['hops']['docker']['cgroup']['enabled'].eql?("true")
  cpu_quota_value = node['hops']['docker']['cgroup']['cpu']['quota']['percentage']
  cpu_quota_period = node['hops']['docker']['cgroup']['cpu']['period']
  docker_cgroup_cpu_cfs_quota_us = (cpu_quota_period * ((cpu_quota_value).to_f / 100) * node['cpu']['total']).to_i

  docker_cgroup_parent = "#{node['hops']['docker']['cgroup']['parent']}"
  docker_memory_cgroup_dir = "#{node['hops']['cgroup']['mount-path']}/memory/#{docker_cgroup_parent}"
  docker_cpu_cgroup_dir = "#{node['hops']['cgroup']['mount-path']}/cpu/#{docker_cgroup_parent}"
  bash "write_cgroup_1" do
    user 'root'
    group 'root'
    code <<-EOH
        echo #{docker_cgroup_cpu_cfs_quota_us} > #{docker_cpu_cgroup_dir}/cpu.cfs_quota_us
        echo #{cpu_quota_period} > #{docker_cpu_cgroup_dir}/cpu.cfs_period_us
        echo #{docker_hard_limit_memory_bytes + excess_memory} > #{docker_memory_cgroup_dir}/memory.limit_in_bytes
        echo #{docker_soft_limit_memory_bytes + excess_memory} > #{docker_memory_cgroup_dir}/memory.soft_limit_in_bytes
    EOH
    not_if "grep -e \"#{node['hops']['cgroup']['mount-path']}[[:space:]]cgroup2\" /proc/mounts"
  end

  bash "write_cgroup_2" do
    user 'root'
    group 'root'
    code <<-EOH
        echo -e "#{docker_cgroup_cpu_cfs_quota_us} #{cpu_quota_period}" > #{node['hops']['cgroup']['mount-path']}/#{docker_cgroup_parent}/cpu.max
        echo #{docker_hard_limit_memory_bytes + excess_memory} > #{node['hops']['cgroup']['mount-path']}/#{docker_cgroup_parent}/memory.max
        echo #{docker_soft_limit_memory_bytes + excess_memory} > #{node['hops']['cgroup']['mount-path']}/#{docker_cgroup_parent}/memory.high
    EOH
    only_if "grep -e \"#{node['hops']['cgroup']['mount-path']}[[:space:]]cgroup2\" /proc/mounts"
  end
end
