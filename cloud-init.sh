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
curl -L https://omnitruck.chef.io/install.sh 2>/dev/null | bash -s -- -c stable -P chef-infra-client 2>/dev/null || \
  apt-get install -y chef 2>/dev/null || \
  (wget -qO- https://packages.chef.io/files/stable/chef-infra-client/18.10.17/debian/11/chef-infra-client_18.10.17-1_amd64.deb > /tmp/chef.deb && dpkg -i /tmp/chef.deb)

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
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACCisxaAozEbGvT1yj5nxgDK/jMFRB43t6uhA6Mx6xmB7QAAAKBGINbVRiDW
1QAAAAtzc2gtZWQyNTUxOQAAACCisxaAozEbGvT1yj5nxgDK/jMFRB43t6uhA6Mx6xmB7Q
AAAEAqKRtT5aRJkSzVuoJBXJxlJVZZYY3rsWARUxR28WPG4KKzFoCjMRsa9PXKPmfGAMr+
MwVEHje3q6EDozHrGYHtAAAAFmNhbWVyb25ATWFjQm9va1Byby5sYW4BAgMEBQYH
-----END OPENSSH PRIVATE KEY-----
DEPLOY_KEY_EOF

chmod 600 /root/.ssh/github_deploy

# Configure SSH to use the deploy key for github.com
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
sudo chef-solo -c solo.rb -j solo.json

echo "=== Chef Solo provisioning completed at $(date) ==="
