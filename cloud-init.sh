#!/bin/bash
set -e

echo "=== Chef Solo Bootstrap for Debian VM ==="
echo "Starting provisioning at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y git openssh-client curl wget

# Install Chef Infra Client from official source
echo "Installing Chef Infra Client..."
echo "Current directory: $(pwd)"
echo "curl version: $(curl --version | head -1)"

# Create temp directory for Chef download
mkdir -p /tmp/chef-install
cd /tmp/chef-install

echo "Attempting to download Chef installer script..."
curl -v -L https://omnitruck.chef.io/install.sh -o install.sh 2>&1 | head -20

if [ -f install.sh ]; then
  echo "Installer script downloaded successfully"
  echo "Script size: $(wc -c < install.sh) bytes"
  
  echo "Running Chef installer..."
  bash install.sh -c stable -P chef-infra-client 2>&1 | tee install.log
  
  if [ $? -eq 0 ]; then
    echo "Chef installation completed"
  else
    echo "Chef installation failed, checking log:"
    tail -20 install.log
  fi
else
  echo "Failed to download Chef installer script"
  exit 1
fi

# Verify installation
if command -v chef-client &> /dev/null; then
  echo "SUCCESS: Chef is installed"
  chef-client --version
else
  echo "ERROR: Chef installation verification failed"
  echo "Checking /opt/chef:"
  ls -la /opt/chef 2>&1 || echo "No /opt/chef directory"
  exit 1
fi

# Clone chef-solo cookbooks
echo "Cloning chef-solo repository..."
CHEF_REPO="/opt/chef-solo"

# Set up SSH
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add GitHub to known_hosts
ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true

# Create deploy key for GitHub access
cat > /root/.ssh/github_deploy << 'DEPLOY_KEY_EOF'
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNDaXN4YUFvekViR3ZUMXlqNW54Z0RLL2pNRlJCNDN0NnVoQTZNeDZ4bUI3UUFBQUtCR0lOYlZSaURXCjFRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ2lzeGFBb3pFYkd2VDF5ajVueGdESy9qTUZSQjQzdDZ1aEE2TXg2eG1CN1EKQUFBRUFxS1J0VDVhUkprU3pWdW9KQlhKeGxKVlpaWVkzcnNXQVJVeFIyOFdQRzRLS3pGb0NqTVJzYTlQWEtQbWZHQU1yKwpNd1ZFSGplM3E2RURvekhyR1lIdEFBQUFGbU5oYldWeWIyNUFUV0ZqUW05dmExQnlieTVzWVc0QkFnTUVCUVlICi0tLS0tRU5EIE9QRU5TU0ggUFJJVkFURSBLRVktLS0tLQo=
DEPLOY_KEY_EOF

# Decode from base64
base64 -d /root/.ssh/github_deploy > /root/.ssh/github_deploy.tmp
mv /root/.ssh/github_deploy.tmp /root/.ssh/github_deploy
chmod 600 /root/.ssh/github_deploy

# Configure SSH for GitHub
cat > /root/.ssh/config << 'SSH_CONFIG_EOF'
Host github.com
  IdentityFile /root/.ssh/github_deploy
  StrictHostKeyChecking no
SSH_CONFIG_EOF

chmod 600 /root/.ssh/config

# Clone the repository
if [ ! -d "$CHEF_REPO" ]; then
  git clone git@github.com:camerongary/chef-solo.git "$CHEF_REPO"
else
  cd "$CHEF_REPO" && git pull
fi

cd "$CHEF_REPO"

# Run Chef Solo
echo "Running Chef Solo..."
chef-solo -c solo.rb -j solo.json

echo "=== Chef Solo provisioning completed successfully at $(date) ==="
