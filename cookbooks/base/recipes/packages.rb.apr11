# Update package manager
execute 'apt-get update' do
  command 'apt-get update'
  action :run
end

# Install required packages
node['base']['packages'].each do |pkg|
  package pkg do
    action :install
  end
end

# Set timezone (optional, adjust as needed)
execute 'set-timezone' do
  command 'timedatectl set-timezone UTC'
  action :run
  only_if { ::File.exist?('/bin/timedatectl') }
end
