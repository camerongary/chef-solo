#!/bin/bash
#
# Chef Solo Provisioning Script for XCP-NG Debian VMs
#
# IMPORTANT: Customize the variables below before using this script!
#
# This script is meant to be used as a "User Config" cloud-init script in XCP-NG.
# Steps to use:
# 1. Customize the variables below (GitHub repo, deploy key, user password)
# 2. Copy the entire contents of this file
# 3. In XCP-NG: New VM -> Debian Cloud Init template
#    -> Install Settings -> Custom Configs -> User config
# 4. Paste this script into the User Config field
# 5. Complete VM creation and boot
#
# The script will automatically download Chef, clone the repository, and run provisioning.
#

set -e

# ============================================================================
# CUSTOMIZE THESE VARIABLES FOR YOUR ENVIRONMENT
# ============================================================================

# GitHub repository owner (user or organization)
GITHUB_OWNER="camerongary"

# GitHub repository name
GITHUB_REPO="chef-solo"

# Git branch to clone
GITHUB_BRANCH="main"

# Munki server URL (where Chef deb package is hosted)
MUNKI_SERVER="http://192.168.12.249"

# Local user configuration
# Choose your username and generate a password hash with: openssl passwd -6
LOCAL_USERNAME="myuser"
local_user_password_hash='$6$CHANGEME$CHANGECHANGECHANGECHANGECHANGECHANGECHANGECHANGECHANGECHANGECHANGECHANGE'

# Chef deb package filename
CHEF_DEB="chef_14.15.6-1_amd64.deb"

# ============================================================================
# GitHub Deploy Key (base64-encoded private key)
# Generate with: ssh-keygen -t ed25519 -f ~/.ssh/github_deploy -N ""
#                cat ~/.ssh/github_deploy | base64
# CHANGE THIS TO YOUR OWN DEPLOY KEY!
# ============================================================================

github_deploy_key_base64='LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNDaXN4YUFvekViR3ZUMXlqNW54Z0RLL2pNRlJCNDN0NnVoQTZNeDZ4bUI3UUFBQUtCR0lOYlZSaURXCjFRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ2lzeGFBb3pFYkd2VDF5ajVueGdESy9qTUZSQjQzdDZ1aEE2TXg2eG1CN1EKQUFBRUFxS1J0VDVhUkprU3pWdW9KQlhKeGxKVlpaWVkzcnNXQVJVeFIyOFdQRzRLS3pGb0NqTVJzYTlQWEtQbWZHQU1yKwpNd1ZFSGplM3E2RURvekhyR1lIdEFBQUFGbU5oYldWeWIyNUFUV0ZqUW05dmExQnlieTVzWVc0QkFnTUVCUVlICi0tLS0tRU5EIE9QRU5TU0ggUFJJVkFURSBLRVktLS0tLQo='

# ============================================================================
# END CUSTOMIZATION SECTION
# ============================================================================

echo "=================================="
echo "Chef Solo Provisioning Script"
echo "=================================="
echo "GitHub: ${GITHUB_OWNER}/${GITHUB_REPO} (${GITHUB_BRANCH})"
echo "Munki: ${MUNKI_SERVER}"
echo ""

# Update system
echo "[1/6] Updating system..."
apt-get update
apt-get upgrade -y
apt-get install -y git openssh-client curl wget

# Download Chef
echo "[2/6] Downloading Chef from Munki..."
wget -O /tmp/${CHEF_DEB} ${MUNKI_SERVER}/${CHEF_DEB}
dpkg -i /tmp/${CHEF_DEB}
rm -f /tmp/${CHEF_DEB}

# Setup SSH for GitHub
echo "[3/6] Setting up GitHub SSH access..."
mkdir -p /root/.ssh
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true

# Decode and write deploy key
echo "${github_deploy_key_base64}" | base64 -d > /root/.ssh/github_deploy
chmod 600 /root/.ssh/github_deploy

# SSH config for GitHub
cat > /root/.ssh/config << 'SSHEOF'
Host github.com
  IdentityFile /root/.ssh/github_deploy
  StrictHostKeyChecking no
SSHEOF
chmod 600 /root/.ssh/config

# Clone repository
echo "[4/6] Cloning Chef repository..."
git clone git@github.com:${GITHUB_OWNER}/${GITHUB_REPO}.git /opt/chef-solo
cd /opt/chef-solo
git checkout ${GITHUB_BRANCH}

# Update user password in solo.json
echo "[5/6] Configuring users..."
# This is handled by the recipe which uses the password hash from solo.json

# Run Chef Solo
echo "[6/6] Running Chef Solo..."
chef-solo -c /opt/chef-solo/solo.rb -j /opt/chef-solo/solo.json

echo ""
echo "=================================="
echo "Provisioning Complete!"
echo "=================================="
echo "SSH Access: ${LOCAL_USERNAME}@<ip>"
echo ""
