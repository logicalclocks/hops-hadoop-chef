

magic_shell_environment 'LD_LIBRARY_PATH' do
  value "#{node.hops.base_dir}/lib/native:$LD_LIBRARY_PATH"
end
