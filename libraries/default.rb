module Hops
  module Helpers
    
    def hopsworks_host
      hopsworks_host = ""
      if node.attribute?("hopsworks")
        hopsworks_ip = private_recipe_ip("hopsworks", "default")
        hopsworks_port = "8181"
        if node['hopsworks'].attribute?(:https) and node['hopsworks']['https'].attribute?(:port)
          hopsworks_port = node['hopsworks']['https']['port']
        end
        hopsworks_host = "https://#{hopsworks_ip}:#{hopsworks_port}"
      end
    end

    def template_ssl_server
      if (node['hops']['rmappsecurity']['jwt']['enabled'].eql?("true") or node['hops']['tls']['enabled'].eql?("true"))
        
        ## Get JWT from kagent
        bearer_jwt = get_service_jwt()
        
        tokenized = bearer_jwt.split(' ').map(&:strip)
        if not tokenized.length.eql? 2
          fail "Could not extract JWT from Hopsworks response"
        end
        hopsworks_jwt = tokenized[1]
      else
        hopsworks_jwt = ""
      end
      
      template "#{node['hops']['conf_dir']}/ssl-server.xml" do
        source "ssl-server.xml.erb"
        owner node['hops']['hdfs']['user']
        group node['kagent']['certs_group']
        mode "770"
        variables({
                    :kstore => "#{node['kagent']['keystore_dir']}/#{node['fqdn']}__kstore.jks",
                    :tstore => "#{node['kagent']['keystore_dir']}/#{node['fqdn']}__tstore.jks",
                    :jwt => hopsworks_jwt
                  })
        action :create
      end
    end
    
  end
end
