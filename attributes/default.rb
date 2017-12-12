include_attribute "ndb"
include_attribute "kzookeeper"

default['hops']['version']                     = "2.8.2.2"

default['hops']['hdfs']['user']                = node['install']['user'].empty? ? "hdfs" : node['install']['user']
default['hops']['group']                       = node['install']['user'].empty? ? "hadoop" : node['install']['user']
default['hops']['secure_group']                = node['install']['user'].empty? ? "metaserver" : node['install']['user']
default['hops']['yarn']['user']                = node['install']['user'].empty? ? "yarn" : node['install']['user']
default['hops']['yarnapp']['user']             = node['install']['user'].empty? ? "yarnapp" : node['install']['user']
default['hops']['rm']['user']                  = node['install']['user'].empty? ? "rmyarn" : node['install']['user']
default['hops']['mr']['user']                  = node['install']['user'].empty? ? "mapred" : node['install']['user']

default['hopsworks']['user']                   = node['install']['user'].empty? ? "glassfish" : node['install']['user']

default['hops']['jmx']['username']             = "monitorRole"
default['hops']['jmx']['password']             = "hadoop"

default['hops']['jmx']['adminUsername']        = "adminRole"
default['hops']['jmx']['adminPassword']        = "hadoopAdmin"

default['hops']['dir']                         = node['install']['dir'].empty? ? "/srv" : node['install']['dir']
default['hops']['base_dir']                    = node['hops']['dir'] + "/hadoop"
default['hops']['home']                        = node['hops']['dir'] + "/hadoop-" + node['hops']['version']
default['hops']['logs_dir']                    = node['hops']['base_dir'] + "/logs"
default['hops']['tmp_dir']                     = node['hops']['base_dir'] + "/tmp"
default['hops']['conf_dir_parent']             = node['hops']['base_dir'] + "/etc"
default['hops']['conf_dir']                    = node['hops']['base_dir'] + "/etc/hadoop"
default['hops']['sbin_dir']                    = node['hops']['base_dir'] + "/sbin"
default['hops']['bin_dir']                     = node['hops']['base_dir'] + "/bin"
default['hops']['data_dir']                    = node['hops']['dir'] + "/hopsdata"
default['hops']['dn']['data_dir']              = "file://" + node['hops']['data_dir'] + "/hdfs/dn"
default['hops']['dn']['data_dir_permissions']  = '700'
default['hops']['nn']['name_dir']              = "file://" + node['hops']['data_dir'] + "/hdfs/nn"

default['hops']['nm']['log_dir']               = node['hops']['logs_dir'] + "/userlogs"

default['hops']['hdfs']['user_home']           = "/user"
default['hops']['hdfs']['blocksize']           = "134217728"

default['hops']['url']['primary']              = node['download_url'] + "/hops-" + node['hops']['version'] + ".tgz"
default['hops']['url']['secondary']            = "https://hops.site/hops-" + node['hops']['version'] + ".tgz"

default['hops']['install_protobuf']            = "false"
default['hops']['protobuf_url']                = "https://protobuf.googlecode.com/files/protobuf-2.5.0.tar.gz"
default['hops']['hadoop_src_url']              = "https://archive.apache.org/dist/hadoop/core/hadoop-" + node['hops']['version'] + "/hadoop-" + node['hops']['version'] + "-src.tar.gz"
default['hops']['nn']['http_port']             = 50070
default['hops']['dn']['http_port']             = 50075
default['hops']['nn']['port']                  = 8020

default['hops']['nn']['format_options']        = "-format -nonInteractive"

default['hops']['leader_check_interval_ms']    = 1000
default['hops']['missed_hb']                   = 1
default['hops']['num_replicas']                = 3
default['hops']['db']                          = "hops"
default['hops']['nn']['scripts']               = %w{ start-nn.sh stop-nn.sh restart-nn.sh root-start-nn.sh hdfs.sh yarn.sh hadoop.sh }
default['hops']['dn']['scripts']               = %w{ start-dn.sh stop-dn.sh restart-dn.sh root-start-dn.sh hdfs.sh yarn.sh hadoop.sh }
default['hops']['max_retries']                 = 0
default['hops']['reformat']                    = "false"
default['hops']['io_buffer_sz']                = 131072
default['hops']['container_cleanup_delay_sec'] = 0

default['hops']['yarn']['scripts']             = %w{ start stop restart root-start }
default['hops']['yarn']['ps_port']             = 20888

case node['platform_family']
when "debian"
default['hops']['yarn']['vpmem_ratio']         = "50.1"
default['hops']['yarn']['vmem_check']          = true
when "rhel"
default['hops']['yarn']['vpmem_ratio']         = "50.1"
default['hops']['yarn']['vmem_check']          = false
end


default['hops']['yarn']['pmem_check']          = true
default['hops']['yarn']['vcores']              = 8
default['hops']['yarn']['min_vcores']          = 1
default['hops']['yarn']['max_vcores']          = 8
default['hops']['yarn']['log_aggregation']     = "true"
default['hops']['yarn']['nodemanager']['remote_app_log_dir'] = node['hops']['hdfs']['user_home'] + "/" + node['hops']['yarn']['user'] + "/logs"
default['hops']['yarn']['log_retain_secs']     = 86400
default['hops']['yarn']['log_retain_check']    = 100

default['hops']['yarn']['container_cleanup_delay_sec']  = 0

default['hops']['yarn']['nodemanager_hb_ms']   = "1000"

default['hops']['am']['max_retries']           = 2

default['hops']['yarn']['aux_services']        = "spark_shuffle,mapreduce_shuffle"

default['hops']['mr']['shuffle_class']         = "org.apache.hadoop.mapred.ShuffleHandler"

default['hops']['yarn']['app_classpath']       = "#{node['hops']['home']},
                                                  #{node['hops']['home']}/lib/*,
                                                  #{node['hops']['home']}/etc/hadoop/,
                                                  #{node['hops']['home']}/share/hadoop/common/*,
                                                  #{node['hops']['home']}/share/hadoop/common/lib/*,
                                                  #{node['hops']['home']}/share/hadoop/hdfs/*,
                                                  #{node['hops']['home']}/share/hadoop/hdfs/lib/*,
                                                  #{node['hops']['home']}/share/hadoop/yarn/*,
                                                  #{node['hops']['home']}/share/hadoop/yarn/lib/*,
                                                  #{node['hops']['home']}/share/hadoop/tools/lib/*,
                                                  #{node['hops']['home']}/share/hadoop/mapreduce/*,
                                                  #{node['hops']['home']}/share/hadoop/mapreduce/lib/*"
#                                                  #{node['hops']['home']}/share/hadoop/yarn/test/*,
#                                                  #{node['hops']['home']}/share/hadoop/mapreduce/test/*"

default['hops']['rm']['addr']                  = []
default['hops']['rm']['http_port']             = 8088
default['hops']['nm']['http_port']             = 8042
default['hops']['jhs']['http_port']            = 19888

#default['hops']['rm']['scheduler_class']       = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.fifo.FifoScheduler"
default['hops']['rm']['scheduler_class']       = "org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler"
default['hops']['rm']['scheduler_capacity']['calculator_class']  = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"

default['hops']['mr']['tmp_dir']               = "/mapreduce"
default['hops']['mr']['staging_dir']           = "#{default['hops']['mr']['tmp_dir']}/#{default['hops']['mr']['user']}/staging"

default['hops']['jhs']['inter_dir']            = "/mr-history/done_intermediate"
default['hops']['jhs']['done_dir']             = "/mr-history/done"

# YARN CONFIG VARIABLES
# http://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-common/yarn-default.xml
# If you need mapreduce, mapreduce.shuffle should be included here.
# You can have a comma-separated list of services
# http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-mapreduce-client/hadoop-mapreduce-client-core/PluggableShuffleAndPluggableSort.html

default['hops']['nn']['jmxport']               = "8077"
default['hops']['rm']['jmxport']               = "8082"
default['hops']['nm']['jmxport']               = "8083"

default['hops']['nn']['public_ips']            = ['10.0.2.15']
default['hops']['nn']['private_ips']           = ['10.0.2.15']
default['hops']['dn']['public_ips']            = ['10.0.2.15']
default['hops']['dn']['private_ips']           = ['10.0.2.15']
default['hops']['rm']['public_ips']            = ['10.0.2.15']
default['hops']['rm']['private_ips']           = ['10.0.2.15']
default['hops']['nm']['public_ips']            = ['10.0.2.15']
default['hops']['nm']['private_ips']           = ['10.0.2.15']
default['hops']['jhs']['public_ips']           = ['10.0.2.15']
default['hops']['jhs']['private_ips']          = ['10.0.2.15']
default['hops']['ps']['public_ips']            = ['10.0.2.15']
default['hops']['ps']['private_ips']           = ['10.0.2.15']

# comma-separated list of namenode addrs
default['hops']['nn']['addrs']                 = []

# build the native libraries. Is much slower, but removes warning when using services.
default['hops']['native_libraries']            = "false"
default['hops']['cgroups']                     = "false"

default['maven']['version']                    = "3.2.5"
default['maven']['checksum']                   = ""


# If yarn.nm.memory_mbs is not set, then memory_percent is used instead
default['hops']['yarn']['memory_mbs']          = 12000
default['hops']['yarn']['memory_percent']      = "75"

default['hops']['limits']['nofile']            = '32768'
default['hops']['limits']['nproc']             = '65536'
default['hops']['limits']['memory_limit']      = '100000'
default['hops']['os_defaults']                 = "true"

default['hops']['user_envs']                   = "true"

default['hops']['logging_level']               = "WARN"
default['hops']['nn']['direct_memory_size']    = 100
default['hops']['ha_enabled']                  = "false"

default['hops']['systemd']                     = "true"

default['hops']['log']['maxfilesize']          = "256MB"
default['hops']['log']['maxbackupindex']       = 10


###################################################################
###################################################################
###################################################################
###################################################################

# set the location of libndbclient.so. set-env.sh sets LD_LIBRARY_PATH to find this library.
default['ndb']['libndb']                    = "#{node['mysql']['version_dir']}/lib"
default['mysql']['port']                    = default['ndb']['mysql_port']
default['hadoop']['mysql_url']              = "jdbc:mysql://#{node['ndb']['mysql_ip']}:#{default['ndb']['mysql_port']}/"

default['hops']['log_level']                = "DEBUG"

default['hops']['hdfs']['blocksize']        = "134217728"

default['dal']['download_url']              = "#{node['download_url']}/ndb-dal-#{node['hops']['version']}-#{node['ndb']['version']}.jar"
default['dal']['lib_url']                   = "#{node['download_url']}/libhopsyarn-#{node['hops']['version']}-#{node['ndb']['version']}.so"
default['nvidia']['download_url']           = "#{node['download_url']}/nvidia-management-#{node['hops']['version']}-#{node['ndb']['version']}.jar"
default['hops']['libnvml_url']              = "#{node['download_url']}/libhopsnvml-#{node['hops']['version']}.so"
default['dal']['schema_url']                = "#{node['download_url']}/hops-#{node['hops']['version']}-#{node['ndb']['version']}.sql"

default['hops']['recipes']                  = %w{ nn dn rm nm jhs ps }

# limits.d settings
default['hops']['limits']['nofile']         = '32768'
default['hops']['limits']['nproc']          = '65536'

default['hops']['jhs']['https']['port']     = "19443"
default['hops']['rm']['https']['port'] 	    = "8090"
default['hops']['nm']['https']['port']      = "45443"

default['hops']['yarn']['resource_tracker'] = "false"
default['hops']['nn']['direct_memory_size'] = 50
default['hops']['nn']['heap_size']          = 500

default['hops']['nn']['public_ips']         = ['10.0.2.15']
default['hops']['nn']['private_ips']        = ['10.0.2.15']
default['hops']['dn']['public_ips']         = ['10.0.2.15']
default['hops']['dn']['private_ips']        = ['10.0.2.15']
default['hops']['rm']['public_ips']         = ['10.0.2.15']
default['hops']['rm']['private_ips']        = ['10.0.2.15']
default['hops']['nm']['public_ips']         = ['10.0.2.15']
default['hops']['nm']['private_ips']        = ['10.0.2.15']
default['hops']['jhs']['public_ips']        = ['10.0.2.15']
default['hops']['jhs']['private_ips']       = ['10.0.2.15']
default['hops']['ps']['public_ips']         = ['10.0.2.15']
default['hops']['ps']['private_ips']        = ['10.0.2.15']
default['hops']['yarn']['resource_tracker'] = "false"

default['hops']['erasure_coding']           = "false"

default['hops']['nn']['cache']                 = "true"
default['hops']['nn']['partition_key']         = "true"

default['vagrant']                       = "false"

default['hops']['reverse_dns_lookup_supported']    = "false"

default['hops']['use_systemd']              = "false"
default['hops']['yarn']['log_aggregation']     = "true"
default['hops']['nn']['format_options']        = "-formatAll"

default['hops']['trash']['interval']           = 360
default['hops']['trash']['checkpoint']['interval']= 60

default['hops']['yarn']['nodemanager_ha_enabled']            = "false"
default['hops']['yarn']['nodemanager_auto_failover_enabled'] = "false"
default['hops']['yarn']['nodemanager_recovery_enabled']      = "true"
# NM heartbeats need to be at least twice as long as NDB transaction timeouts


default['hops']['yarn']['rm_heartbeat']                      = 1000
default['hops']['yarn']['nodemanager_rpc_batch_max_size']    = 60
default['hops']['yarn']['nodemanager_rpc_batch_max_duration']= 60
default['hops']['yarn']['rm_distributed']                    = "false"
default['hops']['yarn']['nodemanager_rm_streaming_enabled']  = "true"
default['hops']['yarn']['client_failover_sleep_base_ms']     = 100
default['hops']['yarn']['client_failover_sleep_max_ms']      = 1000
default['hops']['yarn']['quota_enabled']                     = "true"
default['hops']['yarn']['quota_monitor_interval']            = 1000
default['hops']['yarn']['quota_ticks_per_credit']            = 60
default['hops']['yarn']['quota_min_ticks_charge']            = 600
default['hops']['yarn']['quota_checkpoint_nbticks']          = 600
default['hops']['yarn']['nm_heapsize_mbs']                   = 1000
default['hops']['yarn']['rm_heapsize_mbs']                   = 1000

## SSL Config Attributes##

#hdfs-site.xml
default['hops']['dfs']['https']['enable']                    = "true"
default['hops']['dfs']['http']['policy']   		     = "HTTPS_ONLY"
default['hops']['dfs']['datanode']['https']['address'] 	     = "0.0.0.0:50475"
default['hops']['dfs']['namenode']["https-address"]   	     = "0.0.0.0:50470"

#mapred-site.xml
default['hops']['mapreduce']['jobhistory']['http']['policy'] = "HTTPS_ONLY"
default['hops']['mapreduce']['jobhistory']['webapp']['https']['address']  = "#{node['hops']['jhs']['public_ips']}:#{node['hops']['jhs']['https']['port']}"

#yarn-site.xml
default['hops']['yarn']['http']['policy']                    = "HTTPS_ONLY"
default['hops']['yarn']['log']['server']['url']              = "https://#{node['hops']['jhs']['private_ips']}:#{node['hops']['jhs']['https']['port']}/jobhistory/logs"
default['hops']['yarn']['resourcemanager']['webapp']['https']['address']  = "#{node['hops']['rm']['private_ips']}:#{node['hops']['rm']['https']['port']}"
default['hops']['yarn']['nodemanager']['webapp']['https']['address'] 		= "0.0.0.0:#{node['hops']['nm']['https']['port']}"

#ssl-server.xml
default['hops']['ssl']['server']['keystore']['password']   		= node['hopsworks']['master']['password']
default['hops']['ssl']['server']['keystore']['keypassword']   		= node['hopsworks']['master']['password']

## Keystore and truststore locations are substitued in recipes/default.rb
## They should be removed from here. They are not used anywhere
default['hops']['ssl']['server']['keystore']['location'] 		= "#{node['kagent']['keystore_dir']}/node_server_keystore.jks"
default['hops']['ssl']['server']['truststore']['location']   		= "#{node['kagent']['keystore_dir']}/node_server_truststore.jks"
##

default['hops']['ssl']['server']['truststore']['password']     	 	= node['hopsworks']['master']['password']

#ssl-client.xml

default['hops']['ssl']['client']['truststore']['password']		= node['hopsworks']['master']['password']
default['hops']['ssl']['client']['truststore']['location']		= "#{node['kagent']['keystore_dir']}/node_client_truststore.jks"

# Number of reader threads of the IPC/RPC server
# Default is 1, when TLS is enabled it is advisable to increase it
default['hops']['server']['threadpool'] = 3

# RPC TLS
default['hops']['rpc']['ssl'] = "false"

# Do not verify the hostname
default['hops']['hadoop']['ssl']['hostname']['verifier']                = "ALLOW_ALL"
# Socket factory for the client
default['hops']['hadoop']['rpc']['socket']['factory']                   = "org.apache.hadoop.net.HopsSSLSocketFactory"
default['hops']['hadoop']['ssl']['enabled']['protocols']                = "TLSv1.2,TLSv1.1,TLSv1,SSLv3"

#capacity scheduler queue configuration
default['hops']['capacity']['max_app']                                  = 10000
default['hops']['capacity']['max_am_percent']                           = 0.3
#default['hops']['capacity']['resource_calculator_class']                = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculatorGPU"
default['hops']['capacity']['resource_calculator_class']                = "org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"
default['hops']['capacity']['root_queues']                              = "default"
default['hops']['capacity']['default_capacity']                         = 100
default['hops']['capacity']['user_limit_factor']                        = 1
default['hops']['capacity']['default_max_capacity']                     = 100
default['hops']['capacity']['default_state']                            = "RUNNING"
default['hops']['capacity']['default_acl_submit_applications']          = "*"
default['hops']['capacity']['default_acl_administer_queue']             = "*"
default['hops']['capacity']['queue_mapping']                            = ""
default['hops']['capacity']['queue_mapping_override']['enable']         = "false"


default['hops']['hopsutil_jar']                        = "hops-util.jar"
default['hops']['examples_jar']                        = "hops-spark.jar"
default['hops']['hopsutil_version']                    = "0.1.0"
default['hops']['examples_version']                    = "0.1.0"
default['hops']['hopsutil']['url']                     = "#{node['download_url']}/hops-util-#{node['hops']['hopsutil_version']}.jar"
default['hops']['hops_spark_kafka_example']['url']     = "#{node['download_url']}/hops-spark-#{node['hops']['examples_version']}.jar"

#GPU
default['hops']['yarn']['min_gpus']                    = 0
default['hops']['yarn']['max_gpus']                    = 10
default['hops']['gpu']                                 = "false"
default['hops']['yarn']['gpus']                        = "*"
default['hops']['yarn']['linux_container_local_user']  = node['install']['user'].empty? ? "yarnapp" : node['install']['user']
default['hops']['yarn']['linux_container_limit_users'] = "true"

#Store Small files in NDB
default['hops']['small_files']['store_in_db']                                       = "true"
default['hops']['small_files']['max_size']                                          = 65536
default['hops']['small_files']['on_disk']['max_size']['small']                      = 2000
default['hops']['small_files']['on_disk']['max_size']['medium']                     = 4000
default['hops']['small_files']['on_disk']['max_size']['large']                      = 65536
default['hops']['small_files']['in_memory']['max_size']                             = 1024

default['hopsmonitor']['default']['private_ips']                                    = ['10.0.2.15']
default['hopsworks']['default']['private_ips']                                      = ['10.0.2.15']
