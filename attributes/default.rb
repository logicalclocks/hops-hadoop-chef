include_attribute "kagent"
include_attribute "ndb"

default.hops.version                  = "2.7.3"
default.hops.hdfs.user                = "hdfs"
default.hops.group                    = "hadoop"
default.hops.dir                      = "/srv"
default.hops.base_dir                 = "#{node.hops.dir}/hadoop"
default.hops.home                     = "#{node.hops.dir}/hadoop-#{node.hops.version}"
default.hops.logs_dir                 = "#{node.hops.base_dir}/logs"
default.hops.tmp_dir                  = "#{node.hops.base_dir}/tmp"
default.hops.conf_dir                 = "#{node.hops.base_dir}/etc/hadoop"
default.hops.sbin_dir                 = "#{node.hops.base_dir}/sbin"
default.hops.bin_dir                  = "#{node.hops.base_dir}/bin"
default.hops.data_dir                 = "/var/data/hadoop"
default.hops.dn.data_dir              = "file://#{node.hops.data_dir}/hdfs/dn"
default.hops.nn.name_dir              = "file://#{node.hops.data_dir}/hdfs/nn"

default.hops.nm.log_dir               = "#{node.hops.logs_dir}/userlogs"

default.hops.hdfs.user_home           = "/user"
default.hops.hdfs.active_nn           = true
default.hops.hdfs.blocksize           = "134217728"

default.hops.download_url.primary     = "#{download_url}/hadoop-#{node.hops.version}.tar.gz"
default.hops.download_url.secondary   = "https://archive.apache.org/dist/hadoop/core/hadoop-#{node.hops.version}/hadoop-#{node.hops.version}.tar.gz"

default.hops.install_protobuf         = "false"
default.hops.protobuf_url             = "https://protobuf.googlecode.com/files/protobuf-2.5.0.tar.gz"
default.hops.hadoop_src_url           = "https://archive.apache.org/dist/hadoop/core/hadoop-#{node.hops.version}/hadoop-#{node.hops.version}-src.tar.gz"
default.hops.nn.http_port             = 50070
default.hops.dn.http_port             = 50075
default.hops.nn.port                  = 8020

default.hops.nn.format_options        = "-format -nonInteractive"

default.hops.leader_check_interval_ms = 1000
default.hops.missed_hb                = 1
default.hops.num_replicas             = 3
default.hops.db                       = "hadoop"
default.hops.nn.scripts               = %w{ start-nn.sh stop-nn.sh restart-nn.sh root-start-nn.sh hdfs.sh yarn.sh hadoop.sh } 
default.hops.dn.scripts               = %w{ start-dn.sh stop-dn.sh restart-dn.sh root-start-dn.sh hdfs.sh yarn.sh hadoop.sh } 
default.hops.max_retries              = 0
default.hops.reformat                 = "false"
default.hops.io_buffer_sz             = 131072
default.hops.container_cleanup_delay_sec  = 0

default.hops.nn.heap_size             = 500

default.hops.yarn.scripts             = %w{ start stop restart root-start }
default.hops.yarn.user                = "yarn"
default.hops.yarn.ps_port             = 20888

default.hops.yarn.vpmem_ratio         = 4.1
default.hops.yarn.vmem_check          = false
default.hops.yarn.pmem_check          = true
default.hops.yarn.vcores              = 4
default.hops.yarn.min_vcores          = 1
default.hops.yarn.max_vcores          = 4
default.hops.yarn.log_aggregation     = "true"
default.hops.yarn.nodemanager.remote_app_log_dir = node.hops.hdfs.user_home + "/" + node.hops.yarn.user + "/logs"
default.hops.yarn.log_retain_secs     = 86400
default.hops.yarn.log_retain_check    = 100

default.hops.yarn.container_cleanup_delay_sec  = 0

default.hops.yarn.nodemanager_hb_ms   = "1000"
 
default.hops.am.max_retries           = 2

default.hops.yarn.aux_services        = "mapreduce_shuffle"

default.hops.mr.user                  = "mapred"
default.hops.mr.shuffle_class         = "org.apache.hadoop.mapred.ShuffleHandler"

default.hops.yarn.app_classpath       = "#{node.hops.home}, 
                                                  #{node.hops.home}/lib/*, 
                                                  #{node.hops.home}/etc/hadoop/,  
                                                  #{node.hops.home}/share/hadoop/common/*, 
                                                  #{node.hops.home}/share/hadoop/common/lib/*, 
                                                  #{node.hops.home}/share/hadoop/hdfs/*, 
                                                  #{node.hops.home}/share/hadoop/hdfs/lib/*, 
                                                  #{node.hops.home}/share/hadoop/yarn/*, 
                                                  #{node.hops.home}/share/hadoop/yarn/lib/*, 
                                                  #{node.hops.home}/share/hadoop/tools/lib/*, 
                                                  #{node.hops.home}/share/hadoop/mapreduce/*, 
                                                  #{node.hops.home}/share/hadoop/mapreduce/lib/*"
#                                                  #{node.hops.home}/share/hadoop/yarn/test/*, 
#                                                  #{node.hops.home}/share/hadoop/mapreduce/test/*"

default.hops.rm.addr                  = []
default.hops.rm.http_port             = 8088
default.hops.nm.http_port             = 8042
default.hops.jhs.http_port            = 19888

#default.hops.rm.scheduler_class       = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.fifo.FifoScheduler"
default.hops.rm.scheduler_class       = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler"
default.hops.rm.scheduler_capacity.calculator_class  = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"

default.hops.mr.tmp_dir               = "/mapreduce"
default.hops.mr.staging_dir           = "#{default.hops.mr.tmp_dir}/#{default.hops.mr.user}/staging"

default.hops.jhs.inter_dir            = "/mr-history/done_intermediate"
default.hops.jhs.done_dir             = "/mr-history/done"

# YARN CONFIG VARIABLES
# http://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-common/yarn-default.xml
# If you need mapreduce, mapreduce.shuffle should be included here.
# You can have a comma-separated list of services
# http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-mapreduce-client/hadoop-mapreduce-client-core/PluggableShuffleAndPluggableSort.html

default.hops.nn.jmxport               = "8077"
default.hops.rm.jmxport               = "8082"
default.hops.nm.jmxport               = "8083"

default.hops.jmx.username             = "monitorRole"
default.hops.jmx.password             = "hadoop"


default.hops.nn.public_ips            = ['10.0.2.15']
default.hops.nn.private_ips           = ['10.0.2.15']
default.hops.dn.public_ips            = ['10.0.2.15']
default.hops.dn.private_ips           = ['10.0.2.15']
default.hops.rm.public_ips            = ['10.0.2.15']
default.hops.rm.private_ips           = ['10.0.2.15']
default.hops.nm.public_ips            = ['10.0.2.15']
default.hops.nm.private_ips           = ['10.0.2.15']
default.hops.jhs.public_ips           = ['10.0.2.15']
default.hops.jhs.private_ips          = ['10.0.2.15']
default.hops.ps.public_ips            = ['10.0.2.15']
default.hops.ps.private_ips           = ['10.0.2.15']

# comma-separated list of namenode addrs
default.hops.nn.addrs                 = []

# build the native libraries. Is much slower, but removes warning when using services.
default.hops.native_libraries         = "false"
default.hops.cgroups                  = "false"

default.maven.version                          = "3.2.5"
default.maven.checksum                         = ""


# If yarn.nm.memory_mbs is not set, then memory_percent is used instead
default.hops.yarn.nm.memory_mbs       = 2500
default.hops.yarn.memory_percent      = "75"

default.hops.limits.nofile            = '32768'
default.hops.limits.nproc             = '65536'
default.hops.limits.memory_limit      = '100000'
default.hops.os_defaults              = "true"

default.hops.user_envs                = "true"

default.hops.logging_level            = "WARN"
default.hops.nn.direct_memory_size    = 100
default.hops.ha_enabled               = "false"

default.hops.systemd                  = "true"


default.hops.log.maxfilesize          = "256MB"
default.hops.log.maxbackupindex       = 10


###################################################################
###################################################################
###################################################################
###################################################################

# set the location of libndbclient.so. set-env.sh sets LD_LIBRARY_PATH to find this library.
default.ndb.libndb                           = "#{default.mysql.version_dir}/lib"
default.mysql.port                           = default.ndb.mysql_port
default.hadoop.mysql_url                     = "jdbc:mysql://#{default.ndb.mysql_ip}:#{default.ndb.mysql_port}/"

default.hops.log_level                       = "DEBUG"

default.hops.data_dir                        = "/var/data/hadoop"
default.hops.dn.data_dir                     = "file://#{node.hops.data_dir}/hdfs/dn"
default.hops.hdfs.blocksize                  = "134217728"

default.dal.download_url                     = "#{node.download_url}/ndb-dal-#{node.hops.version}-#{node.ndb.version}.jar"
default.dal.lib_url                          = "#{node.download_url}/libhopsyarn-#{node.hops.version}-#{node.ndb.version}.so"

default.hadoop_spark.version                 = "2.0.1"
default.yarn.spark.shuffle_jar               = "spark-#{node.hadoop_spark.version}-yarn-shuffle.jar"
default.yarn.spark.shuffle_url               = "#{node.download_url}/#{node.yarn.spark.shuffle_jar}"
default.yarn.kafka.util_jar                  = "kafka-util-0.1.jar"
default.yarn.kafka.util_url                  = "#{node.download_url}/#{node.yarn.kafka.util_jar}"
default.dal.schema_url                       = "#{node.download_url}/hops.sql"


default.hops.recipes                         = %w{ nn dn rm nm jhs ps } 

# limits.d settings
default.hops.limits.nofile                   = '32768'
default.hops.limits.nproc                    = '65536'

#default.hops.hadoop_env.hadoop_opts         = '-Djava.net.preferIPv4Stack=true ${HADOOP_OPTS}'
#default.hops.mapred_env.hadoop_opts         = '-Djava.net.preferIPv4Stack=true ${HADOOP_OPTS}'

default.hops.nn.direct_memory_size           = 50
default.hops.nn.heap_size                    = 100

default.hops.nn.public_ips                   = ['10.0.2.15']
default.hops.nn.private_ips                  = ['10.0.2.15']
default.hops.dn.public_ips                   = ['10.0.2.15']
default.hops.dn.private_ips                  = ['10.0.2.15']
default.hops.rm.public_ips                   = ['10.0.2.15']
default.hops.rm.private_ips                  = ['10.0.2.15']
default.hops.nm.public_ips                   = ['10.0.2.15']
default.hops.nm.private_ips                  = ['10.0.2.15']
default.hops.jhs.public_ips                  = ['10.0.2.15']
default.hops.jhs.private_ips                 = ['10.0.2.15']
default.hops.ps.public_ips                   = ['10.0.2.15']
default.hops.ps.private_ips                  = ['10.0.2.15'] 

default.hops.yarn.resource_tracker           = "false"

default.hops.use_hopsworks                   = "false"

default.hops.erasure_coding                  = "false"

default.hops.nn.cache                        = "true"
default.hops.nn.partition_key                = "true"

default.vagrant                              = "false"

node.normal.mysql.user                       = node.mysql.user
node.normal.mysql.password                   = node.mysql.password

default.hops.reverse_dns_lookup_supported    = "false"

default.hops.use_systemd                     = "false"
node.normal.hops.use_systemd        = node.hops.use_systemd


                                                          
default.hops.yarn.nodemanager_ha_enabled            = "false"
default.hops.yarn.nodemanager_auto_failover_enabled = "false"
default.hops.yarn.nodemanager_recovery_enabled      = "true"
# NM heartbeats need to be at least twice as long as NDB transaction timeouts
#default.hops.yarn.rm_heartbeat                     = node.ndb.TransactionInactiveTimeout * 2
default.hops.yarn.rm_heartbeat                      = 2000
default.hops.yarn.nodemanager_rpc_batch_max_size    = 60
default.hops.yarn.nodemanager_rpc_batch_max_duration= 60
default.hops.yarn.rm_distributed                    = "false"
default.hops.yarn.nodemanager_rm_streaming_enabled  = "true"
default.hops.yarn.client_failover_sleep_base_ms     = 100
default.hops.yarn.client_failover_sleep_max_ms      = 1000
default.hops.yarn.quota_enabled                     = "true"
default.hops.yarn.quota_monitor_interval            = 1000
default.hops.yarn.quota_ticks_per_credit            = 60
default.hops.yarn.quota_min_ticks_charge            = 600
default.hops.yarn.quota_checkpoint_nbticks          = 600

node.default.hops.yarn.log_aggregation     = "true"


default.hops.nn.format_options                      = "-formatAll"

default.hops.trash.interval                         = 360
default.hops.trash.checkpoint.interval              = 60

#capacity scheduler queue configuration
default.hops.capacity.max_app                                  =10000
default.hops.capacity.max_am_percent                           =0.3
default.hops.capacity.resource_calculator_class                ="org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"
default.hops.capacity.root_queues                              ="default"
default.hops.capacity.default_capacity                         =100
default.hops.capacity.user_limit_factor                        =1
default.hops.capacity.default_max_capacity                     =100
default.hops.capacity.default_state                            ="RUNNING"
default.hops.capacity.default_acl_submit_applications          ="*"
default.hops.capacity.default_acl_administer_queue             ="*"
default.hops.capacity.queue_mapping                            =""
default.hops.capacity.queue_mapping_override.enable            ="false"






