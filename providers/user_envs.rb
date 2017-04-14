
action :update do

  username="#{@new_resource.name}"

  bash "update_env_variables_for_user" do
    user "#{username}"
    code <<-EOF
# add the environment variables when logging in using non-interactive shell (i.e., using ssh)
# .bash_profile is sourced when logging in with ssh, .bashrc is not sources

cp /home/#{username}/.bashrc /home/#{username}/.bashrc.bak

# make this resource idempotent, by cleaning out old profile
rm /home/#{username}/.bash_profile

echo export JAVA_HOME=#{node.java.java_home} >> /home/#{username}/.bash_profile
echo export HADOOP_INSTALL=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile
# '' (single quoting) a string causes its variables not to be dereferenced
echo 'export PATH=\$PATH:#{node.hops.dir}/hadoop/bin' >> /home/#{username}/.bash_profile
# \\ has the same effect as a single '\' on singly quoted string
echo export PATH=\\$PATH:#{node.hops.dir}/hadoop/sbin >> /home/#{username}/.bash_profile
echo export HADOOP_MAPRED_HOME=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile
echo export HADOOP_COMMON_HOME=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile
echo export HADOOP_HDFS_HOME=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile
echo export YARN_HOME=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile
echo export HADOOP_HOME=#{node.hops.dir}/hadoop >> /home/#{username}/.bash_profile

echo export HADOOP_CONF_DIR=#{node.hops.dir}/hadoop/etc/hadoop >> /home/#{username}/.bash_profile
echo export YARN_CONF_DIR=#{node.hops.dir}/hadoop/etc/hadoop >> /home/#{username}/.bash_profile

echo export HADOOP_PID_DIR=#{node.hops.dir}/hadoop/logs >> /home/#{username}/.bash_profile
echo export YARN_PID_DIR=#{node.hops.dir}/hadoop/logs >> /home/#{username}/.bash_profile

echo export 'HADOOP_CLASSPATH=:.:\$HADOOP_CONF_DIR:\$HADOOP_COMMON_HOME/share/hadoop/common/*:\$HADOOP_COMMON_HOME/share/hadoop/common/lib/*:\$HADOOP_HDFS_HOME/share/hadoop/hdfs/*:\$HADOOP_HDFS_HOME/share/hadoop/hdfs/lib/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/lib/*:\$HADOOP_YARN_HOME/share/hadoop/yarn/test/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/test/*:\$HADOOP_COMMON_HOME/share/hadoop/tools/lib/*' >> /home/#{username}/.bash_profile

echo export 'CLASSPATH=\$HADOOP_CLASSPATH' >> /home/#{username}/.bash_profile

echo "export HADOOP_NAMENODE_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8077 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{username}/.bash_profile

export "HADOOP_DATANODE_OPTS=\\"-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8078 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/jmxremote.password\\" " >> /home/#{username}/.bash_profile

echo "export YARN_OPTS=\\"-Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/yarn-jmxremote.password\\" " >> /home/#{username}/.bash_profile

# Command specific options appended to HADOOP_OPTS when specified
echo "export YARN_RESOURCEMANAGER_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8082 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/yarn-jmxremote.password\\" " >> /home/#{username}/.bash_profile

echo "export YARN_NODEMANAGER_OPTS=\\"-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.port=8083 -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.password.file=\\$HADOOP_CONF_DIR/yarn-jmxremote.password\\" " >> /home/#{username}/.bash_profile
echo export cygwin=false >> /home/#{username}/.bash_profile

export HADOOP_USER_CLASSPATH_FIRST=true >> /home/#{username}/.bash_profile

# Wipe old .bashrc, and add new .bashrc starting with running .bash_profile and then running the old .bashrc
echo "test -f /home/#{username}/.bash_profile && source /home/#{username}/.bash_profile" > /home/#{username}/.bashrc
cat /home/#{username}/.bashrc.bak >> /home/#{username}/.bashrc
rm /home/#{username}/.bashrc.bak

# Create a ssh key, needed for start-dfs.sh and start-yarn.sh
ssh-keygen -t rsa -P '' -f /home/#{username}/.ssh/id_rsa
cat /home/#{username}/.ssh/id_rsa.pub >> /home/#{username}/.ssh/authorized_keys
# Disable need for user confirmation when sshing to a host for the first time. 
# The alternative would be to explicitly add hosts to .ssh/known_hosts file.
echo "\nStrictHostKeyChecking no\n" >> /home/#{username}/.ssh/config

EOF
    not_if { ::File.exist?("/home/#{username}/.ssh/config") }
  end

  
end
