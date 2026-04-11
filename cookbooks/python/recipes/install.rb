# Install Python and related packages

# Install Python from deadsnakes PPA for newer versions (optional)
# For Debian 11+, the default Python is usually sufficient
# Uncomment below if you need a specific version:
#
# execute 'add-deadsnakes-ppa' do
#   command 'apt-get install -y software-properties-common && add-apt-repository ppa:deadsnakes/ppa && apt-get update'
#   action :run
#   not_if { ::File.exist?('/etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-jammy.list') }
# end

# Install Python development packages
%w(python3 python3-dev python3-pip python3-venv).each do |pkg|
  package pkg do
    action :install
  end
end

# Create symbolic links for convenience (optional)
link '/usr/bin/python' do
  to '/usr/bin/python3'
  action :create
  not_if { ::File.exist?('/usr/bin/python') }
end

link '/usr/bin/pip' do
  to '/usr/bin/pip3'
  action :create
  not_if { ::File.exist?('/usr/bin/pip') }
end

# Upgrade pip
execute 'upgrade-pip' do
  command 'python3 -m pip install --upgrade pip'
  action :run
end

# Install pip packages
node['python']['pip_packages'].each do |pkg|
  execute "install-pip-#{pkg}" do
    command "python3 -m pip install #{pkg}"
    action :run
    not_if { `python3 -m pip list`.include?(pkg) }
  end
end
