require 'open3'

module Hops
  module Helpers
    def template_ssl_server(generate_jwt = true)
      if (generate_jwt and (node['hops']['rmappsecurity']['jwt']['enabled'].eql?("true") or node['hops']['tls']['enabled'].eql?("true")))
        
        ## Get service JWT, from kagent-chef/libraries
        master_token, renew_tokens = get_service_jwt()
      else
        master_token = ""
        renew_tokens = []
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
                    :master_token => master_token,
                    :renew_tokens => renew_tokens
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
      cmd = Mixlib::ShellOut.new('docker info | grep "apparmor"')
      cmd.run_command
      if cmd.exitstatus != 0
        apparmor_enabled = false
      end
      return apparmor_enabled
    end
  end
end
