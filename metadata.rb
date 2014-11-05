name             'hops'
maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
license          "GPL 2.0"
description      'Installs/Configures HOPS distribution'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0"

recipe            "hop::nn", "Installs a Hops Namenode"
recipe            "hop::dn", "Installs a Hops Namenode"
recipe            "hop::rm", "Installs a YARN ResourceManager"
recipe            "hop::nm", "Installs a YARN NodeManager"
recipe            "hop::jhs", "Installs a MapReduce JobHistory Server for YARN"
recipe            "hop::ps", "Installs a WebProxy Server for YARN"


depends 'java'
depends 'kagent'
depends 'ndb'
depends 'hostsfile'

%w{ ubuntu debian rhel centos }.each do |os|
  supports os
end

attribute "hop/version",
:description => "Hop version number",
:type => 'string',
:default => "2.4.0"

attribute "yarn/resourcemanager",
:description => "Ip address for the resourcemanager",
:type => 'string',
:default => ""

attribute "hop/mysql_url",
:description => "JDBC address for the MySQL Server without the trailing DB name",
:type => 'string',
:default => ""

attribute "hop/user",
:description => "Username to run hdfs as",
:type => 'string',
:default => "hdfs"

attribute "hop/yarn/user",
:description => "Username to run yarn as",
:type => 'string',
:default => "yarn"

attribute "hop/mr/user",
:description => "Username to run MapReduce as",
:type => 'string',
:default => "mapred"


attribute "mysql/user",
:description => "Mysql server username",
:type => 'string'

attribute "mysql/password",
:description => "MySql server Password",
:type => 'string'

attribute "hop/format",
:description => "Format HDFS: 'hdfs namenode -format'",
:type => 'string',
:default => "true"

