# ---- Configuration variables ----
GUI               = false # Enable/Disable GUI
RAM               = 4096   # Default memory size in MB

# Network configuration
DOMAIN            = ".hops.io"
NETWORK           = "192.168.50."
NETMASK           = "255.255.255.0"

BOX               = 'opscode-ubuntu-14.04'
BOX_URL           = 'https://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_ubuntu-14.04_chef-provisionerless.box'


HOSTS = {
  "nn1" => [NETWORK+"10", RAM, GUI, BOX],
  "nn2" => [NETWORK+"11", RAM, GUI, BOX],
}

# ---- Vagrant configuration ----

Vagrant.configure(2) do |config|
  HOSTS.each do | (name, cfg) |
    ipaddr, ram, gui, box = cfg

    config.vm.define name do |machine|
#      machine.vm.box   = "threatstack/ubuntu-14.04-amd64"
      machine.vm.box_url = BOX_URL
      machine.vm.guest = :ubuntu
      machine.vm.provider "virtualbox" do |vbox|
        vbox.gui    = gui
        vbox.memory = ram
      end

      machine.vm.hostname = name + DOMAIN
      machine.vm.network 'private_network', ip: ipaddr, netmask: NETMASK
    end

    config.vm.provision :chef_solo, :log_level => :debug do |chef|
      chef.log_level = :debug
      chef.cookbooks_path = "/srv/cookbooks"
      chef.json = {
        "ndb" => {
          "mgmd" => { 
     	    "private_ips" => ["192.168.50.10","192.168.50.11"]
	  },
	  "ndbd" =>      { 
   	    "private_ips" => ["192.168.50.10","192.168.50.11"]
	  },
	  "mysqld" =>      { 
   	    "private_ips" => ["192.168.50.10","192.168.50.11"]
	  },
	  "memcached" =>      { 
   	    "private_ips" => ["192.168.50.10","192.168.50.11"]
	  },
          "ndbapi" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
          "public_ips" => ["192.168.50.10","192.168.50.11"],
          "private_ips" => ["192.168.50.10","192.168.50.11"],
          "enabled" => "true",
        },
        "hopsworks" => {
	  "default" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
        },
        "public_ips" => ["192.168.50.10","192.168.50.11"],
        "private_ips" => ["192.168.50.10","192.168.50.11"],
        "hops"  =>    {
	  "rm" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
	  "nn" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
	  "dn" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
	  "nm" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
	  "jhs" =>    { 
       	    "private_ips" => ["192.168.50.10","192.168.50.11"]
          },
          "use_hopsworks" => "true"
        },
        "vagrant" => "enabled"
      }

      chef.add_recipe "kagent::install"
      chef.add_recipe "ndb::install"
      chef.add_recipe "hops::install"
      chef.add_recipe "ndb::mgmd"
      chef.add_recipe "ndb::ndbd"
      chef.add_recipe "ndb::mysqld"
      chef.add_recipe "hops::ndb"
      chef.add_recipe "hops::nn"
      chef.add_recipe "hops::dn"
      chef.add_recipe "hops::rm"
      chef.add_recipe "hops::nm"
    end 

  end # HOSTS-each

end
