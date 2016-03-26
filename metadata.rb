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

attribute "hops/yarn/rm_heartbeat",
:description => "NodeManager heartbeat timeout",
:type => 'string'

attribute "mysql/user",
:description => "Mysql server username",
:type => 'string',
:required => "required"

attribute "mysql/password",
:description => "MySql server Password",
:type => 'string',
:required => "required"

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


#
# wrapper parameters 
#

attribute "apache_hadoop/yarn/nm/memory_mbs",
:display_name => "Apache_Hadoop NodeManager Memory in MB",
:type => 'string'

attribute "apache_hadoop/yarn/vcores",
:display_name => "Apache_Hadoop NodeManager Number of Virtual Cores",
:type => 'string'

attribute "apache_hadoop/yarn/max_vcores",
:display_name => "Hadoop NodeManager Maximum Virtual Cores per container",
:type => 'string'

attribute "apache_hadoop/version",
:display_name => "Hadoop version",
:description => "Version of apache_hadoop",
:type => 'string'

attribute "apache_hadoop/num_replicas",
:display_name => "HDFS replication factor",
:description => "Number of replicates for each file stored in HDFS",
:type => 'string'

attribute "apache_hadoop/container_cleanup_delay_sec",
:display_name => "Cleanup Delay (s)",
:description => "The number of seconds container data is retained after termination",
:type => 'string'

attribute "apache_hadoop/yarn/user",
:display_name => "Username to run yarn as",
:description => "Username to run yarn as",
:type => 'string'

attribute "apache_hadoop/mr/user",
:display_name => "Username to run mapReduce as",
:description => "Username to run mapReduce as",
:type => 'string'

attribute "apache_hadoop/hdfs/user",
:display_name => "Username to run hdfs as",
:description => "Username to run hdfs as",
:type => 'string'

attribute "apache_hadoop/format",
:display_name => "Format HDFS",
:description => "Format HDFS, Run 'hdfs namenode -format",
:type => 'string'

attribute "apache_hadoop/tmp_dir",
:display_name => "Hadoop Temp Dir",
:description => "The directory in which Hadoop stores temporary data, including container data",
:type => 'string'

attribute "apache_hadoop/data_dir",
:display_name => "HDFS Data Dir",
:description => "The directory in which Hadoop's DataNodes store their data",
:type => 'string'

attribute "apache_hadoop/yarn/nodemanager_hb_ms",
:description => "Heartbeat Interval for NodeManager->ResourceManager in ms",
:type => 'string'

attribute "apache_hadoop/container_cleanup_delay_sec",
:display_name => "Cleanup Delay (s)",
:description => "The number of seconds container data is retained after termination",
:type => 'string'

attribute "apache_hadoop/rm/scheduler_class",
:display_name => "YARN scheduler class",
:description => "Java Classname for the Yarn scheduler (fifo, capacity, fair)",
:type => 'string'

attribute "apache_hadoop/rm/scheduler_capacity/calculator_class",
:display_name => "YARN resource calculator class",
:description => "Switch to DominantResourseCalculator for multiple resource scheduling",
:type => 'string'

attribute "apache_hadoop/user_envs",
:description => "Update the PATH environment variable for the hdfs and yarn users to include hadoop/bin in the PATH ",
:type => 'string'

attribute "apache_hadoop/logging_level",
:description => "Log levels are: TRACE, DEBUG, INFO, WARN",
:type => 'string'

attribute "apache_hadoop/nn/heap_size",
:description => "Size of the NameNode heap in MBs",
:type => 'string'

attribute "apache_hadoop/nn/direct_memory_size",
:description => "Size of the direct memory size for the NameNode in MBs",
:type => 'string'

attribute "apache_hadoop/ha_enabled",
:description => "'true' to enable HA, else 'false'",
:type => 'string'

attribute "apache_hadoop/yarn/rt",
:display_name => "Hadoop Resource Tracker enabled on this nodegroup",
:type => 'string'

attribute "apache_hadoop/dir",
:display_name => "Hadoop installation directory",
:type => 'string'
=======
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

