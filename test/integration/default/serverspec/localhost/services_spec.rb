require 'spec_helper'

#describe service('kagent') do  
#  it { should be_running   }
#end 

describe service('namenode') do  
  it { should be_enabled   }
  it { should be_running   }
end 

describe service('datanode') do  
  it { should be_enabled   }
  it { should be_running   }
end 

describe service('resourcemanager') do  
  it { should be_enabled   }
  it { should be_running   }
end 

describe service('nodemanager') do  
  it { should be_enabled   }
  it { should be_running   }
end 

describe service('JobHistoryServer') do  
  it { should be_running   }
end 

describe command("su hdfs -l -c \"/srv/hadoop/bin/hdfs dfs -ls /\"") do
  its (:stdout) { should match /mr-history/ }
end

