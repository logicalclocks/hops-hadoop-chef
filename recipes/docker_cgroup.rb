
docker_cgroup_cpu_cfs_quota_us = -1
docker_cgroup_memory_hard_limit = 9223372036854771712
docker_cgroup_memory_soft_limit = 9223372036854771712
if node['hops']['docker']['cgroup']['enabled'].eql?("true")
  docker_cgroup_memory_hard_limit = "#{node['hops']['docker']['cgroup']['memory']['hard-limit']}"
  docker_cgroup_memory_soft_limit = "#{node['hops']['docker']['cgroup']['memory']['soft-limit']}"
  docker_cgroup_cpu_cfs_quota_us = node['hops']['docker']['cgroup']['cpu']["period"] * (node['hops']['docker']['cgroup']['cpu']['quota'] / 100)
  docker_memory_cgroup_dir = "/sys/fs/cgroup/memory/docker"
  docker_cpu_cgroup_dir = "/sys/fs/cgroup/cpu/docker"
  bash "install_pkgs" do
    user 'root'
    group 'root'
    code <<-EOH
        echo #{docker_cgroup_cpu_cfs_quota_us} > #{docker_cpu_cgroup_dir}/cpu.cfs_quota_us
        echo #{node['hops']['docker']['cgroup']['cpu']["period"]} > #{docker_cpu_cgroup_dir}/cpu.cfs_period_us
        echo #{docker_cgroup_memory_hard_limit} > #{docker_memory_cgroup_dir}/memory.limit_in_bytes
        echo #{docker_cgroup_memory_soft_limit} > #{docker_memory_cgroup_dir}/memory.soft_limit_in_bytes
    EOH
  end
end

docker_cgroup_rewrite_script="docker-cgroup-rewrite.sh"
docker_cgroup_rewrite_script_path="#{node['hops']['base_dir']}/sbin}/#{docker_cgroup_rewrite_script}"
template "#{docker_cgroup_rewrite_script_path}" do
  source "#{docker_cgroup_rewrite_script}.erb"
  owner root
  group root
  mode "500"
  action :create
  variables({
              :cpu_quota => "#{docker_cgroup_cpu_cfs_quota_us}",
            })
end


bash 'add_docker_cgroup_rewrite_docker_service' do
  user 'root'
  code <<-EOH
     systemctl set-property docker.service ExecStartPost=#{docker_cgroup_rewrite_script_path} MEMORY_LIMIT_BYTES \
     #{docker_cgroup_memory_hard_limit} MEMORY_SOFT_LIMIT_BYTES #{docker_cgroup_memory_soft_limit} CPU_QUOTA \
     #{docker_cgroup_cpu_cfs_quota_us}
  EOH
end

service 'docker' do
  action [:restart]
end