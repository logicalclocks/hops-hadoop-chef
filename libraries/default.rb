require 'open3'

module Hops
  module Helpers
    def template_ssl_server(create_api_key = true, requester)
      if (create_api_key and (node['hops']['rmappsecurity']['jwt']['enabled'].eql?("true") or node['hops']['tls']['enabled'].eql?("true")))
        
        # Parse ssl-server.xml and find the value of hops.hopsworks-api-key xml property
        cmd = "cat #{node['hops']['conf_dir']}/ssl-server.xml | grep -A1 'hops.hopsworks-api-key' | awk 'NR==2' | sed 's/<value>//' | sed 's;</value>;;' | tr -d '[:space:]'"
        stdout, s = Open3.capture2(cmd)
        if s.success? && !stdout.empty?
          api_key = stdout
        else
          api_key_params = {
            :name => "hops_#{requester}_#{my_private_ip()}_#{SecureRandom.hex(6)}",
            :scope => "AUTH"
          }
          api_key = create_api_key(node['kagent']['dashboard']['user'], node['kagent']['dashboard']['password'], api_key_params)
        end
      else
        api_key = ""
      end

      fqdn = node['fqdn']
      if node['install']['localhost'].casecmp?("true")
        fqdn = "localhost"
      end

      template "#{node['hops']['conf_dir']}/ssl-server.xml" do
        source "ssl-server.xml.erb"
        owner node['hops']['hdfs']['user']
        group node['hops']['secure_group']
        mode "770"
        variables({
                    :api_key => api_key,
                  })
        action :create
      end
    end
    
    def get_hops_version(hops_version=nil)
      # Set Hops EE version
      if hops_version.nil?
        version = node['hops']['version']
      else
        version = hops_version
      end
      if node['install']['enterprise']['install'].casecmp? "true"
        version_arr = version.split("-")
        version = version_arr[0] + "-EE"
        if version_arr.size > 1
          version = version + "-" + version_arr[1]
        end
      end
      version
    end

    def docker_cgroup_driver()
      if not node['hops']['cgroup-driver'].empty?
        return node['hops']['cgroup-driver']
      end

      # https://hopsworks.atlassian.net/browse/CLOUD-532
      return "cgroupfs"

      _, s = Open3.capture2("grep -e \"#{node['hops']['cgroup']['mount-path']}[[:space:]]cgroup2\" /proc/mounts")
      if s.success?
        if not exists_local("hops", "nm")
          return "systemd"
        end
      end
      return "cgroupfs"
    end

    def is_apparmor_enabled()
      apparmor_enabled = true
      cmd = Mixlib::ShellOut.new('apparmor_status >/dev/null 2>&1')
      cmd.run_command
      if cmd.exitstatus != 0
        apparmor_enabled = false
      end
      return apparmor_enabled
    end
  end
end
