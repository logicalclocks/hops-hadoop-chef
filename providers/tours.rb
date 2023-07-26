action :update_local_cache do 
    cloud_cache_dir = node["hops"]["cloud_tours_cache"]['base_dir']
    directory cloud_cache_dir do
        owner node['hops']['hdfs']['user']
        group node['hops']['group']
        recursive true
        mode '0700'
        action :create
        not_if { ::File.directory?(cloud_cache_dir) }
    end
    
    new_resource.paths.each do |src|
        # dst is infered from the local cache dir 
        dst = "#{cloud_cache_dir}/#{::File.basename(src)}"
        bash "Copy #{src} to #{dst}" do
            user node['hops']['hdfs']['user']
            group node['hops']['group']
            code <<-EOF
                cp -r #{src} #{dst}
            EOF
        end
    end

    tours_info_file = "#{cloud_cache_dir}/#{node["hops"]["cloud_tours_cache"]['info_csv']}"
    old_tours_info = ""
    if ::File.exists?(tours_info_file)
        old_tours_info = "#{::File.read(tours_info_file)}\n"
    end 
    
    new_tours_info = new_resource.paths.zip(new_resource.hdfs_paths).map{|src, dst| ["#{cloud_cache_dir}/#{::File.basename(src)}", dst, new_resource.owner, new_resource.group, new_resource.mode].join(",")}.join("\n")

    tours_info = "#{old_tours_info}#{new_tours_info}"
    file tours_info_file do
        owner node['hops']['hdfs']['user']
        group node['hops']['group']
        mode '600'
        content tours_info.to_s
        action :create
    end
end 