name             'hops'
maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
license          "GPL 2.0"
description      'Installs/Configures HOPS distribution'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0"

#link:<a target='_blank' href='http://%host%:50070/'>Launch the WebUI for the NameNode</a> 
recipe            "hops::nn", "Installs a Hops NameNode"
recipe            "hops::dn", "Installs a Hops DataNode"
#link:<a target='_blank' href='http://%host%:50088/'>Launch the WebUI for the ResourceManager</a>
recipe            "hops::rm", "Installs a YARN ResourceManager"
recipe            "hops::nm", "Installs a YARN NodeManager"
#link:<a target='_blank' href='http://%host%:50030/'>Launch the WebUI for the JobTracker</a>
#link:<a target='_blank' href='http://%host%:51111/'>Launch the WebUI for the HistoryServer</a>
recipe            "hops::jhs", "Installs a MapReduce JobHistory Server for YARN"
recipe            "hops::ps", "Installs a WebProxy Server for YARN"
recipe            "hops::client", "Installs libaries and configuration files for writing HDFS and YARN progams"


depends 'java'
depends 'kagent'
depends 'ndb'
depends 'hadoop'

%w{ ubuntu debian rhel centos }.each do |os|
  supports os
end

attribute "hadoop/version",
:description => "Hop version number",
:type => 'string'

attribute "hdfs/user",
:description => "Username to run hdfs as",
:type => 'string',
:default => "hdfs"

attribute "hadoop/yarn/user",
:description => "Username to run yarn as",
:type => 'string',
:default => "yarn"

attribute "hadoop/rm/scheduler_class",
:description => "Java Classname for the Yarn scheduler (fifo, capacity, fair)",
:type => 'string'

attribute "hadoop/mr/user",
:description => "Username to run MapReduce as",
:type => 'string',
:default => "mapred"

attribute "mysql/user",
:description => "Mysql server username",
:type => 'string'

attribute "mysql/password",
:description => "MySql server Password",
:type => 'string'

attribute "hadoop/format",
:description => "Format HDFS: 'hdfs namenode -format'",
:type => 'string',
:default => "true"

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

