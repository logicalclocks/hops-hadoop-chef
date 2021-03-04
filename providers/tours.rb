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

    new_resource.rel_paths.each do |src|
        dst = "#{cloud_cache_dir}/#{::File.basename(src)}"
        bash "Copy #{src} to #{dst}" do
            user node['hops']['hdfs']['user']
            group node['hops']['group']
            code <<-EOF
                cp -r #{src} #{dst}
            EOF
        end
    end

    new_resource.abs_paths.each do |src, dst|
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


    # dst,user,group,mode
    rel_tours_info = new_resource.rel_tours_info.map{|arr| ["#{cloud_cache_dir}/#{::File.basename(arr[0])}", arr[0], arr[1], arr[2], arr[3]].join(",")}.join("\n")
    # src,dst,user,group,mode
    abs_tours_info = new_resource.abs_tours_info.map{|arr| arr.join(",")}.join("\n")
    
    tours_info = "#{old_tours_info}#{rel_tours_info}#{abs_tours_info.empty? ? "" : "\n"}#{abs_tours_info}"
    file tours_info_file do
        owner node['hops']['hdfs']['user']
        group node['hops']['group']
        mode '600'
        content tours_info.to_s
        action :create
    end
end 