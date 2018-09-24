module Hops
  module Helpers
    
    def hopsworks_host
      hopsworks_host = ""
      if node.attribute?("hopsworks")
        hopsworks_ip = private_recipe_ip("hopsworks", "default")
        hopsworks_port = "8181"
        if node['hopsworks'].attribute?(:secure_port)
          hopsworks_port = node['hopsworks']['secure_port']
        end
        hopsworks_host = "https://#{hopsworks_ip}:#{hopsworks_port}"
      end
    end
  end
end
