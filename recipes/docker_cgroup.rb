docker_cgroup_cpu_cfs_quota_us = -1
docker_cgroup_memory_hard_limit = 9223372036854771712
docker_cgroup_memory_soft_limit = 9223372036854771712
if node['hops']['docker']['cgroup']['enabled'].eql?("true")
  docker_cgroup_memory_hard_limit = "#{node['hops']['docker']['cgroup']['memory']['hard-limit']}"
  docker_cgroup_memory_soft_limit = "#{node['hops']['docker']['cgroup']['memory']['soft-limit']}"
  cpu_quota_value = node['hops']['docker']['cgroup']['cpu']['quota']
  cpu_quota_period = node['hops']['docker']['cgroup']['cpu']["period"]
  docker_cgroup_cpu_cfs_quota_us = (cpu_quota_period * ((cpu_quota_value).to_f / 100)).to_i
  docker_memory_cgroup_dir = "/sys/fs/cgroup/memory/docker"
  docker_cpu_cgroup_dir = "/sys/fs/cgroup/cpu/docker"
  bash "install_pkgs" do
    user 'root'
    group 'root'
    code <<-EOH
        echo #{docker_cgroup_cpu_cfs_quota_us} > #{docker_cpu_cgroup_dir}/cpu.cfs_quota_us
        echo #{cpu_quota_period} > #{docker_cpu_cgroup_dir}/cpu.cfs_period_us
        echo #{docker_cgroup_memory_hard_limit} > #{docker_memory_cgroup_dir}/memory.limit_in_bytes
        echo #{docker_cgroup_memory_soft_limit} > #{docker_memory_cgroup_dir}/memory.soft_limit_in_bytes
    EOH
  end
end

docker_cgroup_rewrite_script="docker-cgroup-rewrite.sh"
docker_cgroup_rewrite_script_path="#{node['hops']['dir']}/sbin/#{docker_cgroup_rewrite_script}"
template "#{docker_cgroup_rewrite_script_path}" do
  source "#{docker_cgroup_rewrite_script}.erb"
  owner "root"
  group "root"
  mode "500"
  action :create
end

case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/docker-cgroup-rewrite.service"
else
  systemd_script = "/lib/systemd/system/docker-cgroup-rewrite.service"
end

service_name = "docker-cgroup-rewrite"

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

template systemd_script do
  source "#{service_name}.service.erb"
  owner "root"
  group "root"
  mode 0664
  variables({
              'docker_cgroup_rewrite_script' => docker_cgroup_rewrite_script_path,
              'memory_limit_bytes' => docker_cgroup_memory_hard_limit,
              'memory_soft_limit_bytes' => docker_cgroup_memory_soft_limit,
              'cpu_quota' => docker_cgroup_cpu_cfs_quota_us
            })
  if node['services']['enabled'] == "true"
    notifies :enable, "service[#{service_name}]"
  end
end

kagent_config "docker-cgroup-rewrite" do
  action :systemd_reload
end

