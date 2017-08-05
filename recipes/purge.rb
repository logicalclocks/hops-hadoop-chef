daemons = %w{namenode datanode resourcemanager nodemanager historyserver proxyserver}
daemons.each { |d| 
  bash 'uninstall_service_#{d}' do
    user "root"
    ignore_failure true
    code <<-EOF
 service #{d} stop
 systemctl stop #{d}
 pkillall -9 #{d}
EOF
  end

  file "/etc/init.d/#{d}" do
    action :delete
    ignore_failure true
  end
  file "/usr/lib/systemd/systemd/#{d}.service" do
    action :delete
    ignore_failure true
  end
  file "/lib/systemd/systemd/#{d}.service" do
    action :delete
    ignore_failure true
  end
  file "/etc/systemd/system/#{d}.service" do
    action :delete
    ignore_failure true
  end
  directory "/etc/systemd/system/#{d}.service.d" do
    recursive true
    action :delete
    ignore_failure true
  end

}

directory "#{node.hops.dir}/hadoop-#{node.hops.version}" do
  recursive true
  action :delete
  ignore_failure true
end

link node.hops.home do
  action :delete
  ignore_failure true
end

directory node.hops.data_dir do
  recursive true
  action :delete
  ignore_failure true
end

directory Chef::Config.file_cache_path do
  recursive true
  action :delete
  ignore_failure true
end

package "Bouncy Castle Remove" do
  case node.platform
  when 'redhat', 'centos'
    package_name 'bouncycastle'
  when 'ubuntu', 'debian'
    package_name 'bouncycastle'
  end
 ignore_failure true
 action :purge
end


primary_url = node.hops.download_url.secondary
base_package_filename = File.basename(primary_url)
cached_package_filename = "/tmp/#{base_package_filename}"

file cached_package_filename do
  action :delete
  ignore_failure true
end


link "#{node.hops.dir}/ndb-hops" do
  action :delete
  ignore_failure true
end

directory "#{node.hops.dir}/ndb-hops-#{node.hops.version}-#{node.ndb.version}" do
  recursive true
  action :delete
  ignore_failure true
end

