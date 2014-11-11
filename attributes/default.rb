default[:hadoop][:version]                 = default[:hadoop][:version]
default[:hadoop][:user]                    = "hdfs"
default[:hadoop][:group]                   = "hadoop"
default[:hadoop][:dir]                     = "/srv"
default[:hadoop][:home]                    = "#{default[:hadoop][:dir]}/hadoop-#{default[:hadoop][:version]}"
default[:hadoop][:logs_dir]                = "#{default[:hadoop][:home]}/logs"
default[:hadoop][:tmp_dir]                 = "#{default[:hadoop][:home]}/tmp"
default[:hadoop][:conf_dir]                = "#{default[:hadoop][:home]}/etc/hadoop"

default[:hadoop][:download_url]            = "#{default[:download_url]}/hop-#{default[:hadoop][:version]}.tgz"
default[:hadoop][:protobuf_url]         = "https://protobuf.googlecode.com/files/protobuf-2.5.0.tar.gz"
default[:hadoop][:hadoop_src_url]       = "#{default[:download_url]}/hadoop-#{default[:hadoop][:version]}-src.tar.gz"

default[:hadoop][:nn][:http_port]          = 50070
default[:hadoop][:dn][:http_port]          = 50075

default[:hadoop][:storage_type]            = "clusterj"
default[:hadoop][:leader_check_interval_ms]= 1000
default[:hadoop][:missed_hb]               = 1
default[:hadoop][:repl]                    = 1
default[:hadoop][:db]                      = "hop"
default[:hadoop][:nn][:scripts]            = %w{ format-nn.sh start-nn.sh stop-nn.sh restart-nn.sh root-start-nn.sh hdfs.sh yarn.sh hadoop.sh } 
default[:hadoop][:dn][:scripts]            = %w{ start-dn.sh stop-dn.sh restart-dn.sh root-start-dn.sh hdfs.sh yarn.sh hadoop.sh } 
default[:hadoop][:max_retries]             = 0
default[:hadoop][:format]                  = "true"
default[:hadoop][:io_buffer_sz]            = 131072

# set the location of libndbclient.so. set-env.sh sets LD_LIBRARY_PATH to find this library.
default[:ndb][:libndb]                  = "#{default[:mysql][:version_dir]}/lib"
default[:mysql][:port]                  = default[:ndb][:mysql_port]
default[:hadoop][:mysql_url]               = "jdbc:mysql://#{default[:ndb][:mysql_ip]}:#{default[:ndb][:mysql_port]}/"

default[:hadoop][:yarn][:scripts]          = %w{ start stop restart root-start }
default[:hadoop][:yarn][:user]             = "yarn"
default[:hadoop][:yarn][:nm][:memory_mbs]  = 1000
default[:hadoop][:yarn][:ps_port]          = 20888

default[:hadoop][:yarn][:vpmem_ratio]      = 2.1
default[:hadoop][:yarn][:vcores]           = 2
default[:hadoop][:yarn][:min_vcores]       = 1
default[:hadoop][:yarn][:max_vcores]       = 4
default[:hadoop][:yarn][:log_retain_secs]  = 10800

default[:hadoop][:am][:max_retries]        = 2

default[:hadoop][:yarn][:aux_services]     = "mapreduce_shuffle"
default[:hadoop][:mr][:shuffle_class]      = "org.apache.hadoop.mapred.ShuffleHandler"

default[:hadoop][:yarn][:app_classpath]    = "#{default[:hadoop][:home]}/etc/hadoop/, #{default[:hadoop][:home]}, #{default[:hadoop][:home]}/lib/*, #{default[:hadoop][:home]}/share/hadoop/yarn/test/*, #{default[:hadoop][:home]}/share/hadoop/yarn/*, #{default[:hadoop][:home]}/share/hadoop/yarn/lib/*, #{default[:hadoop][:home]}/share/hadoop/mapreduce/*, #{default[:hadoop][:home]}/share/hadoop/mapreduce/lib/*, , #{default[:hadoop][:home]}/share/hadoop/mapreduce/test/*, #{default[:hadoop][:home]}/share/hadoop/common/lib/*, #{default[:hadoop][:home]}/share/hadoop/hdfs/lib/*, #{default[:hadoop][:home]}/share/hadoop/tools/lib/*, #{default[:hadoop][:home]}/share/hadoop/common/*, , #{default[:hadoop][:home]}/share/hadoop/common/*, #{default[:hadoop][:home]}/share/hadoop/hdfs/*, #{default[:hadoop][:home]}/share/hadoop/mapreduce/*"


default[:hadoop][:rm][:http_port]          = 8088
default[:hadoop][:nm][:http_port]          = 8042
default[:hadoop][:jhs][:http_port]         = 19888


default[:hadoop][:mr][:staging_dir]        = "/user"
default[:hadoop][:mr][:tmp_dir]            = "/tmp/hadoop/mapreduce"
default[:hadoop][:jhs][:inter_dir]         = "/mr-history/tmp"
default[:hadoop][:jhs][:done_dir]          = "/mr-history/done"

# YARN CONFIG VARIABLES
# http://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-common/yarn-default.xml
# If you need mapreduce, mapreduce.shuffle should be included here.
# You can have a comma-separated list of services
# http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-mapreduce-client/hadoop-mapreduce-client-core/PluggableShuffleAndPluggableSort.html

default[:hadoop][:nn][:jmxport]            = "8077"
default[:hadoop][:rm][:jmxport]            = "8082"
default[:hadoop][:nm][:jmxport]            = "8083"

default[:hadoop][:jmx][:username]          = "monitorRole"
default[:hadoop][:jmx][:password]          = "hop"

default[:hadoop][:mr][:user]               = "mapred"

default[:hadoop][:nn][:public_ips]         = ['10.0.2.15']
default[:hadoop][:nn][:private_ips]        = ['10.0.2.15']
default[:hadoop][:dn][:public_ips]         = ['10.0.2.15']
default[:hadoop][:dn][:private_ips]        = ['10.0.2.15']
default[:hadoop][:rm][:public_ips]         = ['10.0.2.15']
default[:hadoop][:rm][:private_ips]        = ['10.0.2.15']
default[:hadoop][:nm][:public_ips]         = ['10.0.2.15']
default[:hadoop][:nm][:private_ips]        = ['10.0.2.15']
default[:hadoop][:jhs][:public_ips]        = ['10.0.2.15']
default[:hadoop][:jhs][:private_ips]       = ['10.0.2.15']
default[:hadoop][:ps][:public_ips]         = ['10.0.2.15']
default[:hadoop][:ps][:private_ips]        = ['10.0.2.15']

# build the native libraries. Is much slower, but removes warning when using services.
default[:hadoop][:native_libraries]        = "false"
default[:kagent][:enabled]               = "false"
