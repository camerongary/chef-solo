#!/bin/bash
set -e

echo "=== Chef Solo Bootstrap for Debian VM ==="
echo "Starting provisioning at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y git openssh-client curl wget

# Install Chef Infra Client from local Munki server
echo "Installing Chef Infra Client from local server..."

mkdir -p /tmp/chef-install
cd /tmp/chef-install

# Download Chef deb from Munki server
echo "Downloading Chef from http://192.168.12.249/chef_14.15.6-1_amd64.deb..."
wget http://192.168.12.249/chef_14.15.6-1_amd64.deb

if [ -f chef_14.15.6-1_amd64.deb ]; then
  echo "Chef deb downloaded successfully"
  dpkg -i chef_14.15.6-1_amd64.deb
  apt-get install -f -y
else
  echo "ERROR: Failed to download Chef deb"
  exit 1
fi

# Verify Chef installation
if command -v chef-client &> /dev/null; then
  echo "SUCCESS: Chef Infra Client installed"
  chef-client --version
else
  echo "ERROR: Chef installation verification failed"
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
#LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNDaXN4YUFvekViR3ZUMXlqNW54Z0RLL2pNRlJCNDN0NnVoQTZNeDZ4bUI3UUFBQUtCR0lOYlZSaURXCjFRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ2lzeGFBb3pFYkd2VDF5ajVueGdESy9qTUZSQjQzdDZ1aEE2TXg2eG1CN1EKQUFBRUFxS1J0VDVhUkprU3pWdW9KQlhKeGxKVlpaWVkzcnNXQVJVeFIyOFdQRzRLS3pGb0NqTVJzYTlQWEtQbWZHQU1yKwpNd1ZFSGplM3E2RURvekhyR1lIdEFBQUFGbU5oYldWeWIyNUFUV0ZqUW05dmExQnlieTVzWVc0QkFnTUVCUVlICi0tLS0tRU5EIE9QRU5TU0ggUFJJVkFURSBLRVktLS0tLQo=
c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU5jZTVwUWp3RGRjajJCRWJNQVpra2JNbzJ2bzVEUk0xalBzVzIvelhtUEYgY2FtZXJvbkBDYW1lcm9ucy1NMS1NYWNCb29rLVByby5sb2NhbAo=
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

# Create cameron user with password
useradd -m -s /bin/bash cameron 2>/dev/null || true
echo "cameron:bike2work" | chpasswd

# Add cameron to sudo group
usermod -aG sudo cameron

# Allow passwordless sudo for cameron
echo "cameron ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-cameron
chmod 440 /etc/sudoers.d/90-cameron

# Run Chef Solo
echo "Running Chef Solo..."
chef-solo -c solo.rb -j solo.json

echo "=== Chef Solo provisioning completed successfully at $(date) ==="
echo "You can now SSH in as:"
echo "  Username: cameron"
echo "  Password: bike2work"
