available_memory_in_host_bytes = (node['memory']['total'].gsub("kB","").to_i/10241024) * 1073741824
docker_default_hard_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['hard-limit-default'].gsub("GB", "").to_i) * 1073741824
docker_dedault_soft_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['soft-limit-default'].gsub("GB", "").to_i) * 1073741824
docker_hard_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['hard-limit'].gsub("GB", "").to_i) * 1073741824
docker_soft_limit_memory_bytes = (node['hops']['docker']['cgroup']['memory']['soft-limit'].gsub("GB", "").to_i) * 1073741824
# dyanamic memory allocation
available_memory_in_host_bytes = available_memory_in_host_bytes - docker_hard_limit_memory_bytes
excess_memory = available_memory_in_host_bytes - (30 * 1073741824)
if excess_memory < 0 || (docker_default_hard_limit_memory_bytes != docker_hard_limit_memory_bytes || docker_dedault_soft_limit_memory_bytes != docker_soft_limit_memory_bytes)
  excess_memory = 0
end
excess_memory = (excess_memory/4).round()

node.override['hops']['docker']['cgroup']['memory']['hard-limit'] = ((docker_hard_limit_memory_bytes + excess_memory)/1073741824).to_s + "GB"
node.override['hops']['docker']['cgroup']['memory']['soft-limit'] = ((docker_soft_limit_memory_bytes + excess_memory) /1073741824).to_s + "GB"

if node['hops']['docker']['cgroup']['enabled'].eql?("true")
  cpu_quota_value = node['hops']['docker']['cgroup']['cpu']['quota']
  cpu_quota_period = node['hops']['docker']['cgroup']['cpu']["period"]
  docker_cgroup_cpu_cfs_quota_us = (cpu_quota_period * ((cpu_quota_value).to_f / 100)).to_i
  docker_memory_cgroup_dir = "/sys/fs/cgroup/memory/docker"
  docker_cpu_cgroup_dir = "/sys/fs/cgroup/cpu/docker"
  bash "write_cgroup" do
    user 'root'
    group 'root'
    code <<-EOH
        echo #{docker_cgroup_cpu_cfs_quota_us} > #{docker_cpu_cgroup_dir}/cpu.cfs_quota_us
        echo #{cpu_quota_period} > #{docker_cpu_cgroup_dir}/cpu.cfs_period_us
        echo #{docker_hard_limit_memory_bytes + excess_memory} > #{docker_memory_cgroup_dir}/memory.limit_in_bytes
        echo #{docker_soft_limit_memory_bytes + excess_memory} > #{docker_memory_cgroup_dir}/memory.soft_limit_in_bytes
    EOH
  end
end
