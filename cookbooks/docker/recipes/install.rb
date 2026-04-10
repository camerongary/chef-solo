# Install Docker prerequisites
%w[apt-transport-https ca-certificates curl gnupg lsb-release].each do |pkg|
  package pkg do
    action :install
  end
end

# Add Docker GPG key
execute 'add-docker-gpg-key' do
  command 'curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'
  action :run
  not_if { ::File.exist?('/usr/share/keyrings/docker-archive-keyring.gpg') }
end

# Add Docker repository
file '/etc/apt/sources.list.d/docker.list' do
  content "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian #{node['lsb']['codename']} stable\n"
  action :create
  notifies :run, 'execute[apt-get update]', :immediately
end

# Update apt cache after adding repository
execute 'apt-get update' do
  command 'apt-get update'
  action :nothing
end

# Install Docker Engine
%w[docker-ce docker-ce-cli containerd.io docker-compose-plugin].each do |pkg|
  package pkg do
    action :install
  end
end

# Start and enable Docker service
service 'docker' do
  action [:enable, :start]
end

# Add users to docker group (for rootless access)
node['docker']['users'].each do |user|
  execute "add-#{user}-to-docker-group" do
    command "usermod -aG docker #{user}"
    action :run
    not_if { `groups #{user}`.include?('docker') }
  end
end
