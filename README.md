# Chef Solo Cookbook for XCP-NG Debian VM Provisioning

Automated infrastructure provisioning using Chef Solo and cloud-init on Debian VMs running on XCP-NG hypervisor.

## Quick Start

### Prerequisites
- XCP-NG hypervisor with Debian Cloud-Init template
- Internet connectivity to GitHub
- Customized cloud-init.sh for your environment

### Step 1: Customize cloud-init.sh

Edit `cloud-init.sh` and update these variables to match your environment:

```bash
# Line 27: GitHub username (for private repo access)
GITHUB_OWNER="camerongary"

# Line 29: GitHub repository name
GITHUB_REPO="chef-solo"

# Line 31: Git branch
GITHUB_BRANCH="main"

# Lines 50-52: Set your local username and password hash
# Generate a password hash with: openssl passwd -6
LOCAL_USERNAME="myuser"
local_user_password_hash='$6$YOUR_HASH_HERE'
```

Also update the SSH deploy key (lines 54-62) with your own GitHub deploy key.

### Step 2: Create a Cloud Config in XCP-NG

1. Open XCP-NG web console
2. Go to **Home** → **VMs**
3. Select your pool
4. Click **New VM**
5. Select **Debian Cloud Init** from templates
6. Under **Install Settings**, click **Custom Configs** → **User config**
7. Paste the entire contents of your customized `cloud-init.sh` into the User Config field
8. Customize disk and network settings as needed
9. Click **Create**

### Step 3: Boot and Provision

1. Start the VM
2. Cloud-init will automatically:
   - Download Chef from your Munki server
   - Clone this repository via SSH with the deploy key
   - Run Chef Solo with all configured cookbooks
3. SSH into the VM when provisioning completes

## Development

### Linting Recipes

Validate your cookbooks with cookstyle:

```bash
cookstyle cookbooks/
```

Auto-fix correctable issues:

```bash
cookstyle cookbooks/ -a
```

### Repository Structure

```
chef-solo/
├── cookbooks/
│   ├── base/
│   │   ├── metadata.rb
│   │   └── recipes/
│   │       ├── packages.rb    (base packages, timezone)
│   │       └── users.rb       (admin/cameron users)
│   ├── docker/
│   │   ├── metadata.rb
│   │   └── recipes/
│   │       └── install.rb     (Docker CE setup)
│   └── python/
│       ├── metadata.rb
│       └── recipes/
│           └── install.rb     (Python3, pip, venv)
├── solo.rb                      (Chef Solo config)
├── solo.json                    (run list & attributes)
├── cloud-init.sh               (XCP-NG provisioning script)
└── README.md
```

### Adding Packages

Edit `solo.json` and add to the `base.packages` array:

```json
{
  "base": {
    "packages": [
      "curl",
      "wget",
      "git",
      "vim",
      "htop",
      "net-tools",
      "build-essential",
      "your-package-here"
    ]
  }
}
```

### Modifying Recipes

Edit files in `cookbooks/<cookbook>/recipes/` and commit:

```bash
git add cookbooks/
git commit -m "Update recipes"
git push
```

Next provisioned VMs will use the updated recipes automatically via cloud-init.

## Configuration

- **Chef version**: 14.15.6 (served from Munki server)
- **Hypervisor**: XCP-NG
- **Template**: Debian Cloud-Init (Bullseye or Bookworm)
- **Deploy key**: GitHub SSH deploy key (base64-encoded in cloud-init.sh)
- **Munki server**: http://192.168.12.249
- **Local user**: Customizable in cloud-init.sh (choose your own username and password)

## Customization

Before using this in your environment, you must:

1. **Update cloud-init.sh**:
   - Change `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_BRANCH` to match your setup
   - Choose a `LOCAL_USERNAME` and generate a password hash with `openssl passwd -6`
   - Generate a new GitHub deploy key and update the base64-encoded private key
   - Update Munki server URL if different

2. **Update solo.json**:
   - Add/remove packages as needed
   - Customize user details in the base recipe

3. **Create a GitHub deploy key**:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/github_deploy -N ""
   cat ~/.ssh/github_deploy.pub  # Add this as read-only deploy key on GitHub
   cat ~/.ssh/github_deploy | base64  # Use in cloud-init.sh
   ```

## Troubleshooting

Check cloud-init logs on the VM:

```bash
tail -f /var/log/cloud-init-output.log
```

Check Chef logs:

```bash
tail -f /var/log/chef-solo.log
```

View Chef stacktrace:

```bash
cat /opt/chef-solo/cache/chef-stacktrace.out
```

## License

MIT
