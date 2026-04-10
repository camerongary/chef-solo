# Ensure admin user exists (typically ubuntu for cloud images)
user node['base']['admin_user'] do
  shell '/bin/bash'
  home "/home/#{node['base']['admin_user']}"
  action :create
  not_if { ::File.exist?("/home/#{node['base']['admin_user']}") }
end

# Create .ssh directory with proper permissions
directory "/home/#{node['base']['admin_user']}/.ssh" do
  owner node['base']['admin_user']
  group node['base']['admin_group']
  mode '0700'
  action :create
  only_if { ::File.exist?("/home/#{node['base']['admin_user']}") }
end

# Grant sudo access
execute 'grant-sudo-access' do
  command "usermod -aG sudo #{node['base']['admin_user']}"
  action :run
  not_if { `groups #{node['base']['admin_user']}`.include?('sudo') }
end

# Allow passwordless sudo for admin user (optional - comment out if not needed)
file '/etc/sudoers.d/90-admin-user' do
  content "#{node['base']['admin_user']} ALL=(ALL) NOPASSWD: ALL\n"
  owner 'root'
  group 'root'
  mode '0440'
  action :create
end
