#!/bin/bash
set -e

echo "=== Chef Solo Bootstrap for Debian VM ==="
echo "Starting provisioning at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install git (needed for cloning repo)
apt-get install -y git openssh-client

# Install Chef Infra Client
echo "Installing Chef Infra Client..."

# Try the official Chef installer first
if ! command -v chef-client &> /dev/null; then
  curl -L https://omnitruck.chef.io/install.sh 2>/dev/null | bash -s -- -c stable -P chef-infra-client 2>/dev/null || true
fi

# If still not installed, try apt
if ! command -v chef-client &> /dev/null; then
  apt-get install -y chef 2>/dev/null || true
fi

# If still not installed, try downloading the deb directly
if ! command -v chef-client &> /dev/null; then
  wget -qO /tmp/chef.deb https://packages.chef.io/files/stable/chef-infra-client/18.10.17/debian/11/chef-infra-client_18.10.17-1_amd64.deb
  dpkg -i /tmp/chef.deb
  apt-get install -f -y
fi

# Verify Chef is installed
chef-client --version

# Clone chef-solo cookbooks
echo "Cloning chef-solo repository..."
CHEF_REPO="/opt/chef-solo"

# Set up SSH
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add GitHub to known_hosts (to avoid SSH prompt)
ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true

# Decode and create deploy key for GitHub access
cat > /root/.ssh/github_deploy << 'DEPLOY_KEY_EOF'
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNDaXN4YUFvekViR3ZUMXlqNW54Z0RLL2pNRlJCNDN0NnVoQTZNeDZ4bUI3UUFBQUtCR0lOYlZSaURXCjFRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ2lzeGFBb3pFYkd2VDF5ajVueGdESy9qTUZSQjQzdDZ1aEE2TXg2eG1CN1EKQUFBRUFxS1J0VDVhUkprU3pWdW9KQlhKeGxKVlpaWVkzcnNXQVJVeFIyOFdQRzRLS3pGb0NqTVJzYTlQWEtQbWZHQU1yKwpNd1ZFSGplM3E2RURvekhyR1lIdEFBQUFGbU5oYldWeWIyNUFUV0ZqUW05dmExQnlieTVzWVc0QkFnTUVCUVlICi0tLS0tRU5EIE9QRU5TU0ggUFJJVkFURSBLRVktLS0tLQo=
DEPLOY_KEY_EOF

# Decode from base64
base64 -d /root/.ssh/github_deploy > /root/.ssh/github_deploy.tmp
mv /root/.ssh/github_deploy.tmp /root/.ssh/github_deploy

chmod 600 /root/.ssh/github_deploy

# Configure SSH to use the deploy key for github.com
cat > /root/.ssh/config << 'SSH_CONFIG_EOF'
Host github.com
  IdentityFile /root/.ssh/github_deploy
  StrictHostKeyChecking no
SSH_CONFIG_EOF

chmod 600 /root/.ssh/config

if [ ! -d "$CHEF_REPO" ]; then
  git clone git@github.com:camerongary/chef-solo.git "$CHEF_REPO"
else
  cd "$CHEF_REPO" && git pull
fi

cd "$CHEF_REPO"

# Run Chef Solo
echo "Running Chef Solo..."
/opt/chef/bin/chef-solo -c solo.rb -j solo.json

echo "=== Chef Solo provisioning completed at $(date) ==="
