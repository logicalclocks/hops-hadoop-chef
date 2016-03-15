name             "hops"
maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
license          "GPL 2.0"
description      'Installs/Configures HOPS distribution'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.1"

#link:<a target='_blank' href='http://%host%:50070/'>Launch the WebUI for the NameNode</a> 
recipe            "hops::nn", "Installs a Hops NameNode"
recipe            "hops::dn", "Installs a Hops DataNode"
#link:<a target='_blank' href='http://%host%:8088/'>Launch the WebUI for the ResourceManager</a>
recipe            "hops::rm", "Installs a YARN ResourceManager"
recipe            "hops::nm", "Installs a YARN NodeManager"
recipe            "hops::jhs", "Installs a MapReduce JobHistory Server for YARN"
recipe            "hops::ps", "Installs a WebProxy Server for YARN"
recipe            "hops::rt", "Installs a ResourceTracker server for YARN"
recipe            "hops::client", "Installs libaries and configuration files for writing HDFS and YARN progams"
recipe            "hops::purge", "Removes all hops-hadoop files and dirs and ndb-dal, but doesnt drop hops db from NDB"
recipe            "hops::purge-ndb", "Drops  hops db from NDB"

depends 'java'
depends 'kagent'
depends 'ndb'
depends 'apache_hadoop'

%w{ ubuntu debian rhel centos }.each do |os|
  supports os
end

#attribute "apache_hadoop/version",
#:description => "Hop version number",
#:type => 'string'

attribute "apache_hadoop/hdfs/user",
:description => "Username to run hdfs as",
:type => 'string'

attribute "apache_hadoop/yarn/user",
:description => "Username to run yarn as",
:type => 'string'

attribute "hops/yarn/rm_heartbeat",
:description => "NodeManager heartbeat timeout",
:type => 'string'

# attribute "apache_hadoop/rm/scheduler_class",
# :description => "Java Classname for the Yarn scheduler (fifo, capacity, fair)",
# :type => 'string'

attribute "apache_hadoop/mr/user",
:description => "Username to run MapReduce as",
:type => 'string'

attribute "mysql/user",
:description => "Mysql server username",
:type => 'string',
:required => "required"

attribute "mysql/password",
:description => "MySql server Password",
:type => 'string',
:required => "required"

attribute "apache_hadoop/format",
:description => "Format HDFS: 'hdfs namenode -format'",
:type => 'string'

attribute "hops/use_hopsworks",
:description => "'true' or 'false' - true to enable HopsWorks support",
:type => 'string'

attribute "hops/erasure_coding",
:description => "'true' or 'false' - true to enable erasure-coding replication",
:type => 'string'

attribute "hops/nn/direct_memory_size",
:description => "Size of the direct memory size for the NameNode in MBs",
:type => 'string'

attribute "hops/nn/heap_size",
:description => "Size of the NameNode heap in MBs",
:type => 'string'

attribute "hops/nn/cache",
:description => "'true' or 'false' - true to enable the path cache in the NameNode",
:type => 'string'

attribute "hops/nn/partition_key",
:description => "'true' or 'false' - true to enable the partition key when starting transactions. Distribution-aware transactions.",
:type => 'string'

attribute "hops/yarn/resource_tracker",
:display_name => "Hadoop Resource Tracker enabled on this nodegroup",
:type => 'string'

attribute "hops/install_db",
:display_name => "Install hops database and tables in MySQL Cluster ('true' (default) or 'false')",
:type => 'string'

attribute "hops/dir",
:display_name => "Base installation directory for HopsFS",
:type => 'string'


attribute "hops/use_systemd",
:description => "Use systemd startup scripts, default 'false'",
:type => "string"

attribute "apache_hadoop/data_dir",
:description => "Directory to store actual hadoop data",
:type => "string"


attribute "hops/yarn/rm_distributed",
:description => "Set to 'true' for distribute yarn",
:type => "string"


attribute "hops/yarn/nodemanager_ha_enabled",
:description => "",
:type => "string"

attribute "hops/yarn/nodemanager_auto_failover_enabled",
:description => "",
:type => "string"

attribute "hops/yarn/nodemanager_recovery_enabled",
:description => "",
:type => "string"

attribute "hops/yarn/rm_heartbeat",
:description => "",
:type => "string"

attribute "hops/yarn/nodemanager_rpc_batch_max_size",
:description => "",
:type => "string"

attribute "hops/yarn/nodemanager_rpc_batch_max_duration",
:description => "",
:type => "string"

attribute "hops/yarn/rm_distributed",
:description => "Set to 'true' to enable distributed RMs",
:type => "string"

attribute "hops/yarn/nodemanager_rm_streaming_enabled",
:description => "",
:type => "string"

attribute "hops/yarn/client_failover_sleep_base_ms",
:description => "",
:type => "string"

attribute "hops/yarn/client_failover_sleep_max_ms",
:description => "",
:type => "string"

attribute "hops/yarn/quota_enabled",
:description => "",
:type => "string"

attribute "hops/yarn/quota_monitor_interval",
:description => "",
:type => "string"

attribute "hops/yarn/quota_ticks_per_credit",
:description => "",
:type => "string"

attribute "hops/yarn/quota_min_ticks_charge",
:description => "",
:type => "string"

attribute "hops/yarn/quota_checkpoint_nbticks",
:description => "",
:type => "string"

