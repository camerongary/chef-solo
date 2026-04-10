#!/bin/bash
set -e

echo "=== Chef Solo Bootstrap for Debian VM ==="
echo "Starting provisioning at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install git (needed for cloning repo)
apt-get install -y git

# Install Chef Infra Client
echo "Installing Chef Infra Client..."
curl -L https://omnitruck.chef.io/install.sh 2>/dev/null | bash -s -- -c stable -P chef-infra-client 2>/dev/null || \
  apt-get install -y chef 2>/dev/null || \
  (wget -qO- https://packages.chef.io/files/stable/chef-infra-client/18.10.17/debian/11/chef-infra-client_18.10.17-1_amd64.deb > /tmp/chef.deb && dpkg -i /tmp/chef.deb)

# Clone chef-solo cookbooks
echo "Cloning chef-solo repository..."
CHEF_REPO="/opt/chef-solo"

# Add GitHub to known_hosts (to avoid SSH prompt)
mkdir -p /root/.ssh
ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true

if [ ! -d "$CHEF_REPO" ]; then
  git clone git@github.com:camerongary/chef-solo.git "$CHEF_REPO"
else
  cd "$CHEF_REPO" && git pull
fi

cd "$CHEF_REPO"

# Run Chef Solo
echo "Running Chef Solo..."
sudo chef-solo -c solo.rb -j solo.json

echo "=== Chef Solo provisioning completed at $(date) ==="
