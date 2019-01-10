name             "hops"
maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
license          "Apache v2.0"
description      'Installs/Configures the Hops distribution'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.9.0"
source_url       "https://github.com/hopshadoop/hops-hadoop-chef"


#link:<a target='_blank' href='http://%host%:50070/'>Launch the WebUI for the NameNode</a>
recipe            "hops::nn", "Installs a HopsFs NameNode"
recipe            "hops::ndb", "Installs MySQL Cluster (ndb) dal driver for Hops"
recipe            "hops::dn", "Installs a HopsFs DataNode"
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
depends 'magic_shell'
depends 'sysctl'
depends 'cmake'
depends 'kzookeeper'
depends 'hopsmonitor'

%w{ ubuntu debian rhel centos }.each do |os|
  supports os
end

attribute "hops/dir",
          :description => "Base installation directory for HopsFS",
          :type => 'string'

attribute "mysql/user",
          :description => "Mysql server username",
          :type => 'string',
          :required => "required"

attribute "mysql/password",
          :description => "MySql server Password",
          :type => 'string',
          :required => "required"

attribute "hops/erasure_coding",
          :description => "'true' or 'false' - true to enable erasure-coding replication",
          :type => 'string'

attribute "hops/nn/cache",
          :description => "'true' or 'false' - true to enable the path cache in the NameNode",
          :type => 'string'

attribute "hops/nn/partition_key",
          :description => "'true' or 'false' - true to enable the partition key when starting transactions. Distribution-aware transactions.",
          :type => 'string'

attribute "hops/yarn/resource_tracker",
          :description => "Hadoop Resource Tracker enabled on this nodegroup",
          :type => 'string'

attribute "hops/install_db",
          :description => "Install hops database and tables in MySQL Cluster ('true' (default) or 'false')",
          :type => 'string'

attribute "hops/use_systemd",
          :description => "Use systemd startup scripts, default 'false'",
          :type => "string"

attribute "hops/format",
          :description => "'true' to format HDFS, 'false' to skip formatting",
          :type => 'string'

attribute "hops/reformat",
          :description => "'true' to re-format HDFS, 'false' to skip re-formatting",
          :type => 'string'

attribute "hops/yarn/memory_mbs",
          :description => "Apache_Hadoop NodeManager Memory in MB",
          :type => 'string'

attribute "hops/yarn/nodemanager_log_dir",
          :description => "The directory in which yarn node manager store containers logs",
          :type => 'string'

attribute "hops/yarn/nodemanager_recovery_dir",
          :description => "The directory in which yarn node manager stores recovery state",
          :type => 'string'

attribute "hops/yarn/nodemanager_ha_enabled",
          :description => "",
          :type => "string"

attribute "hops/yarn/nodemanager_auto_failover_enabled",
          :description => "",
          :type => "string"

attribute "hops/yarn/nodemanager_recovery_enabled",
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

attribute "hops/yarn/rm_heartbeat",
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

attribute "hops/yarn/quota_threshold_gpu",
          :description => "",
          :type => "string"

attribute "hops/yarn/quota_minimum_charged_mb",
          :description => "",
          :type => "string"

attribute "hops/yarn/quota_variable_price_enabled",
          :description => "",
          :type => "string"

attribute "hops/yarn/nm_heapsize_mbs",
          :description => "Increase this value if using the YARN external shuffle service. (default: 1000)",
          :type => 'string'

attribute "hops/yarn/rm_heapsize_mbs",
          :description => "Resource manager heapsize. (default: 1000)",
          :type => 'string'

attribute "hops/yarn/container_executor",
          :description => "Container executor class",
          :type => 'string'

attribute "hops/trash/interval",
          :description => "How long in minutes trash survives in /user/<glassfish>/.Trash/<interval-bucket>/...",
          :type => "string"

attribute "hops/trash/checkpoint/interval",
          :description => "How long in minutes until a new directory bucket is created in /user/<glassfish>/.Trash with a timestamp. ",
          :type => "string"

attribute "hops/nn/private_ips",
          :description => "Set ip addresses",
          :type => "array"

attribute "hops/nn/public_ips",
          :description => "Set ip addresses",
          :type => "array"

attribute "hops/rm/private_ips",
          :description => "Set ip addresses",
          :type => "array"

attribute "hops/rm/public_ips",
          :description => "Set ip addresses",
          :type => "array"

# Needed to find the jar file for yan-spark-shuffle
attribute "hadoop_spark/version",
          :description => "Spark version",
          :type => 'string'

attribute "hops/url/primary",
          :description => "Primary download url of hops distribution",
          :type => 'string'

attribute "hops/url/secondary",
          :description => "Secondary download url of hops distribution",
          :type => 'string'

attribute "hops/server/threadpool",
          :description => "Number of threads in RPC server reading from socket",
          :type => 'string'

attribute "hops/tls/enabled",
          :description => "'true' will enable RPC TLS and 'false' will disable it",
          :type => 'string'

attribute "hops/tls/certs_actor_class",
          :description => "Actor class to perform X509 requests to Hopsworks",
          :type => 'string'

attribute "hops/tls/certs_expiration_safety_period",
          :description => "Time to substract fro X509 expiration time for renewal",
          :type => 'string'

attribute "hops/tls/certs_revocation_monitor_interval",
          :description => "Period to check for stale X509 certificates that should be revoked",
          :type => 'string'

attribute "hops/tls/crl_enabled",
          :description => "Enable CRL validation when RPC TLS is enabled",
          :type => 'string'

attribute "hops/tls/crl_fetcher_class",
          :description => "Canonical name of the CRL fetcher class",
          :type => 'string'

attribute "hops/tls/crl_input_uri",
          :description => "Location where the CRL will be fetched from",
          :type => 'string'

attribute "hops/tls/crl_output_file",
          :description => "Location where the CRL will be stored",
          :type => 'string'

attribute "hops/tls/crl_fetcher_interval",
          :description => "Interval for the CRL fetcher service, suffix can be m/h/d",
          :type => 'string'

attribute "hops/encrypt_data_transfer/enabled",
          :description => "Enable encryption for Data Tranfer Protocol of DataNodes",
          :type => 'string'

attribute "hops/encrypt_data_transfer/algorithm",
          :description => "Encryption algorithm, 3des or rc4",
          :type => 'string'

attribute "hops/yarn/vcores",
          :description => "Hops NodeManager Number of Virtual Cores",
          :type => 'string'

attribute "hops/yarn/min_vcores",
          :description => "Hadoop NodeManager Minimum Virtual Cores per container",
          :type => 'string'

attribute "hops/yarn/max_vcores",
          :description => "Hadoop NodeManager Maximum Virtual Cores per container",
          :type => 'string'

attribute "hops/yarn/log_retain_secs",
          :description => "Default time (in seconds) to retain log files on the NodeManager",
          :type => 'string'

attribute "hops/yarn/log_retain_check",
          :description =>"Default time (in seconds) between checks for retained log files in HDFS.",
          :type => 'string'

attribute "hops/yarn/log_roll_interval",
          :description =>"Defines how often NMs wake up to upload log files. The minimum rolling-interval-seconds can be set is 3600.",
          :type => 'string'

attribute "hops/version",
          :description => "Version of hops",
          :type => 'string'

attribute "hops/num_replicas",
          :description => "Number of replicates for each file stored in HDFS",
          :type => 'string'

attribute "hops/container_cleanup_delay_sec",
          :description => "The number of seconds container data is retained after termination",
          :type => 'string'

attribute "hops/group",
          :description => "Group to run hdfs/yarn/yarnapp/mr as",
          :type => 'string'

attribute "hops/yarn/user",
          :description => "Username to run yarn as",
          :type => 'string'

attribute "hops/yarnapp/user",
          :description => "Username to run yarn applications as",
          :type => 'string'

attribute "hops/mr/user",
          :description => "Username to run mapReduce as",
          :type => 'string'

attribute "hops/hdfs/user",
          :description => "Username to run hdfs as",
          :type => 'string'

attribute "hops/hdfs/superuser_group",
          :description => "Group for users with hdfs superuser privileges",
          :type => 'string'

attribute "hops/hdfs/blocksize",
          :description => "HDFS Blocksize (128k, 512m, 1g, etc). Default 128m.",
          :type => 'string'

attribute "hops/hdfs/umask",
          :description => "Set the default HDFS umask (default: 0022).",
          :type => 'string'

attribute "hops/format",
          :description => "Format HDFS, Run 'hdfs namenode -format",
          :type => 'string'

attribute "hops/tmp_dir",
          :description => "The directory in which Hadoop stores temporary data, including container data",
          :type => 'string'

attribute "hops/nn/name_dir",
          :description => "Directory for NameNode's state",
          :type => 'string'

attribute "hops/dn/data_dir",
          :description => "The directory in which Hadoop's DataNodes store their data",
          :type => 'string'

attribute "hops/data_dir",
          :description => "The directory in which Hadoop's main data files are stored (including hops/dn/data_dir)",
          :type => 'string'

attribute "hops/dn/data_dir_permissions",
          :description => "The permissions for the directory in which Hadoop's DataNodes store their data (default: 700)",
          :type => 'string'

attribute "hops/yarn/nodemanager_hb_ms",
          :description => "Heartbeat Interval for NodeManager->ResourceManager in ms",
          :type => 'string'

attribute "hops/rm/scheduler_class",
          :description => "Java Classname for the Yarn scheduler (fifo, capacity, fair)",
          :type => 'string'

attribute "hops/user_envs",
          :description => "Update the PATH environment variable for the hdfs and yarn users to include hadoop/bin in the PATH ",
          :type => 'string'

attribute "hops/logging_level",
          :description => "Log levels are: TRACE, DEBUG, INFO, WARN",
          :type => 'string'

attribute "hops/nn/heap_size",
          :description => "Size of the NameNode heap in MBs",
          :type => 'string'

attribute "hops/nn/direct_memory_size",
          :description => "Size of the direct memory size for the NameNode in MBs",
          :type => 'string'

attribute "hops/yarn/aux_services",
          :description => "mapreduce_shuffle, spark_shuffle",
          :type => "string"

attribute "hops/capacity/max_ap",
          :description => "Maximum number of applications that can be pending and running.",
          :type => "string"
attribute "hops/capacity/max_am_percent",
          :description => "Maximum percent of resources in the cluster which can be used to run application masters i.e. controls number of concurrent running applications.",
          :type => "string"
attribute "hops/capacity/resource_calculator_class",
          :description => "The ResourceCalculator implementation to be used to compare Resources in the scheduler. The default i.e. DefaultResourceCalculator only uses Memory while DominantResourceCalculator uses dominant-resource to compare multi-dimensional resources such as Memory, CPU etc.",
          :type => "string"
attribute "hops/capacity/root_queues",
          :description => "The queues at the root level (root is the root queue).",
          :type => "string"
attribute "hops/capacity/default_capacity",
          :description => "Default queue target capacity.",
          :type => "string"
attribute "hops/capacity/user_limit_factor",
          :description => " Default queue user limit a percentage from 0.0 to 1.0.",
          :type => "string"
attribute "hops/capacity/default_max_capacity",
          :description => "The maximum capacity of the default queue.",
          :type => "string"
attribute "hops/capacity/default_state",
          :description => "The state of the default queue. State can be one of RUNNING or STOPPED.",
          :type => "string"
attribute "hops/capacity/default_acl_submit_applications",
          :description => "The ACL of who can submit jobs to the default queue.",
          :type => "string"
attribute "hops/capacity/default_acl_administer_queue",
          :description => "The ACL of who can administer jobs on the default queue.",
          :type => "string"
attribute "hops/capacity/queue_mapping",
          :description => "A list of mappings that will be used to assign jobs to queues The syntax for this list is [u|g]:[name]:[queue_name][,next mapping]* Typically this list will be used to map users to queues, for example, u:%user:%user maps all users to queues with the same name as the user.",
          :type => "string"
attribute "hops/capacity/queue_mapping_override.enable",
          :description => "If a queue mapping is present, will it override the value specified by the user? This can be used by administrators to place jobs in queues that are different than the one specified by the user. The default is false.",
          :type => "string"

attribute "kagent/enabled",
          :description => "Set to 'true' to enable, 'false' to disable kagent",
          :type => "string"

attribute "mysql/dir",
          :description => "MySQL installation directory.",
          :type => "string"

attribute "install/dir",
          :description => "Set to a base directory under which we will install.",
          :type => "string"

attribute "install/user",
          :description => "User to install the services as",
          :type => "string"

attribute "influxdb/graphite/port",
          :description => "Port for influxdb graphite connector",
          :type => "string"

#GPU settings
attribute "hops/yarn/min_gpus",
          :description => "Min number of GPUs per container",
          :type => "string"

attribute "hops/yarn/max_gpus",
          :description => "Max number of GPUs per container",
          :type => "string"

attribute "hops/gpu",
          :description => "Are GPUs enabled for YARN? (on this node) Default: false",
          :type => "string"

attribute "hops/yarn/gpus",
          :description => "'*' default: use all GPUs on the host. Otherwise, specify the number  of GPUs per host (e.g., '4'). Otherwise, specify a comma-separated list of minor device-ids:  '0,1,2' or '0-3')",
          :type => "string"

attribute "hops/yarn/cluster/gpu",
          :description => "Is there a machine in the cluster with gpus?",
          :type => "string"

#CGroups settings
attribute "hops/yarn/groups",
          :description => "",
          :type => "string"

attribute "hops/yarn/linux_container_local_user",
          :description => "the user running the yarn containers",
          :type => "string"

attribute "hops/yarn/linux_container_limit_users",
          :description => "",
          :type => "string"

attribute "hops/hopsutil_version",
          :description => "Version of the hops-util jar file.",
          :type => "string"

attribute "hops/hopsexamples_version",
          :description => "Version of the hops-spark jar file.",
          :type => "string"

attribute "hops/yarn/cgroups",
          :description => "'true' to enable cgroups (default), else 'false'",
          :type => "string"

attribute "livy/user",
          :description => "Livy user that will be a proxy user",
          :type => "string"

attribute "hopsworks/user",
          :description => "Hopsworks username",
          :type => "string"

attribute "hops/jmx/adminPassword",
          :description => "Password for JMX admin role",
          :type => "string"

attribute "hopsmonitor/default/private_ips",
          :description => "Hopsworks username",
          :type => "string"

attribute "hopsworks/default/private_ips",
          :description => "Hopsworks private ip",
          :type => "string"

# Kernel tuning parameters
attribute "hops/kernel/somaxconn",
          :description => "net.core.somaxconn value",
          :type => "string"

attribute "hops/kernel/swappiness",
          :description => "vm.swappiness value",
          :type => "string"

attribute "hops/kernel/overcommit_memory",
          :description => "vm.overcommit_memory value",
          :type => "string"

attribute "hops/kernel/overcommit_ratio",
          :description => "vm.overcommit_ratio value",
          :type => "string"
