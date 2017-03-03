
Vagrant.configure("2") do |c|
  if Vagrant.has_plugin?("vagrant-omnibus")
#    require 'vagrant-omnibus'
    c.omnibus.chef_version = "12.4.3"
  end
  if Vagrant.has_plugin?("vagrant-cachier")
    c.omnibus.cache_packages = true        
    c.cache.scope = :machine
    c.cache.auto_detect = false
    c.cache.enable :apt
    c.cache.enable :gem    
  end
   c.vm.box = "bento/ubuntu-16.04"  
#  c.vm.box = "opscode-ubuntu-14.04"
#  c.vm.box_url = "http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_ubuntu-14.04_chef-provisionerless.box"
#   c.vm.box = "bento/centos-7.2"
#  c.vm.box_url = "https://atlas.hashicorp.com/ubuntu/boxes/trusty64/versions/20150924.0.0/providers/virtualbox.box"
#  c.vm.hostname = "default-ubuntu-1404.vagrantup.com"
 
   
  c.ssh.insert_key="false"
# Ssh port on vagrant
  c.vm.network(:forwarded_port, {:guest=>22, :host=>2223})
  c.vm.network(:forwarded_port, {:guest=>8090, :host=>8090})
# MySQL Server
  c.vm.network(:forwarded_port, {:guest=>9090, :host=>33444})

  c.vm.network(:forwarded_port, {:guest=>3306, :host=>8888})
# HTTP webserver
  c.vm.network(:forwarded_port, {:guest=>8080, :host=>8080})
# HTTPS webserver
  c.vm.network(:forwarded_port, {:guest=>8181, :host=>15009})
# Glassfish webserver
  c.vm.network(:forwarded_port, {:guest=>4848, :host=>4848})
# HDFS webserver
  c.vm.network(:forwarded_port, {:guest=>50070, :host=>50071})
# Datanode 
  c.vm.network(:forwarded_port, {:guest=>50075, :host=>50079})
# YARN webserver
  c.vm.network(:forwarded_port, {:guest=>8088, :host=>8088})
# Elasticsearch rpc port
  c.vm.network(:forwarded_port, {:guest=>9200, :host=>9200})
# Flink webserver
  c.vm.network(:forwarded_port, {:guest=>9088, :host=>9088})
# Glassfish Debugger port
  c.vm.network(:forwarded_port, {:guest=>9009, :host=>9191})
# Ooozie port
  c.vm.network(:forwarded_port, {:guest=>11000, :host=>11000})
# Dr Elephant
#  c.vm.network(:forwarded_port, {:guest=>11011, :host=>11011})
# Spark History Server
  c.vm.network(:forwarded_port, {:guest=>18080, :host=>18080})
# Kibana Server
  c.vm.network(:forwarded_port, {:guest=>5601, :host=>50070})
# Grafana Server
  c.vm.network(:forwarded_port, {:guest=>3000, :host=>50075})
# Graphite WebServer
  c.vm.network(:forwarded_port, {:guest=>3000, :host=>8181})
# Logstash Server
#  c.vm.network(:forwarded_port, {:guest=>3000, :host=>8181})
  
  c.vm.provider :virtualbox do |p|
    p.customize ["modifyvm", :id, "--memory", "5000"]
    p.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    p.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    p.customize ["modifyvm", :id, "--nictype1", "virtio"]
    p.customize ["modifyvm", :id, "--cpus", "2"]   
  end


   c.vm.provision :chef_solo do |chef|
     chef.cookbooks_path = "cookbooks"
     chef.json = {
     "ntp" => {
          "install" => "true"
     },
     "mysql" => {
          "dir" => "/srv/hops"
     },
     "ndb" => {
          "user" => "glassfish",
          "group" => "glassfish",
          "dir" => "/srv/hops",
          "mgmd" => { 
     	  	       "private_ips" => ["10.0.2.15"]
	       },
	  "ndbd" =>      { 
   	  	       "private_ips" => ["10.0.2.15"]
	       },
	  "mysqld" =>      { 
   	  	       "private_ips" => ["10.0.2.15"]
	       },
	  "memcached" =>      { 
   	  	       "private_ips" => ["10.0.2.15"]
	       },
          "public_ips" => ["10.0.2.15"],
          "private_ips" => ["10.0.2.15"],
          "enabled" => "true",
     },
     "hops"  =>    {
                 "dir" => "/srv/hops",
		 "use_hopsworks" => "true",
		 "rm" =>    { 
       	  	      "private_ips" => ["10.0.2.15"]
                 },
		 "nn" =>    { 
       	  	      "private_ips" => ["10.0.2.15"]
                 },
		 "dn" =>    { 
       	  	      "private_ips" => ["10.0.2.15"]
                 },
		 "nm" =>    { 
       	  	      "private_ips" => ["10.0.2.15"]
                 },
		 "jhs" =>    { 
       	  	      "private_ips" => ["10.0.2.15"]
                 },
     	        "hdfs" => {
                      "user" => "glassfish"
                 },
     	        "yarn" => {
		      "user" => "glassfish"
		 },
		 "mr" => {
		      "user" => "glassfish"
                 },
                 "data_dir" => "/srv/hops/data",
      },
     "kagent" => {
	  "user" => "glassfish",
          "group" => "glassfish",
          "dir" => "/srv/hops",
          "allow_ssh_access" => "true",
          "enabled" => "true",
	  "default" =>      { 
   	  	       "private_ips" => ["10.0.2.15"]
	       },
     },
     "vagrant" => "true",
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
      chef.add_recipe "hops::jhs"

  end 

end

