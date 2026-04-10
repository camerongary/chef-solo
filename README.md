# Chef Solo - XCP-NG VM Provisioning

Chef Solo cookbooks for provisioning Debian VMs on XCP-NG with Docker and Python.

## Directory Structure

```
chef-solo/
├── cookbooks/
│   ├── base/              # Base system configuration
│   │   ├── metadata.rb
│   │   └── recipes/
│   │       ├── packages.rb
│   │       └── users.rb
│   ├── docker/            # Docker Engine installation
│   │   ├── metadata.rb
│   │   └── recipes/
│   │       └── install.rb
│   └── python/            # Python installation
│       ├── metadata.rb
│       └── recipes/
│           └── install.rb
├── solo.rb               # Chef Solo configuration
├── solo.json             # Chef Solo attributes and run-list
├── cloud-init.sh         # Cloud-init bootstrap script for XCP-NG
└── README.md
```

## Quick Start

### Local Testing (macOS)

1. Ensure Chef Workstation is installed:
   ```bash
   brew install chef-workstation
   ```

2. Validate cookbooks:
   ```bash
   cookstyle cookbooks/
   ```

3. Lint your recipes:
   ```bash
   chef exec cookbooks/
   ```

### XCP-NG VM Provisioning

1. When creating a new VM in XCP-NG, paste the contents of `cloud-init.sh` into the cloud-init user-data field

2. Or, provide it as a script URL if you host it on your Munki server:
   ```
   https://your-server/chef-solo/cloud-init.sh
   ```

3. The script will:
   - Update system packages
   - Install Chef Infra Client
   - Clone this repository
   - Run Chef Solo to configure the VM

## Customization

### Attributes (solo.json)

Edit `solo.json` to customize:

- **Packages**: Add/remove in `base.packages`
- **Admin User**: Change `base.admin_user` (default: ubuntu)
- **Docker Users**: Add users to `docker.users` for rootless Docker access
- **Python Version**: Change `python.version` as needed
- **Additional Pip Packages**: Add to `python.pip_packages`

### Adding New Recipes

1. Create a new cookbook:
   ```bash
   chef generate cookbook cookbooks/mycookbook
   ```

2. Add recipe to `cookbooks/mycookbook/recipes/default.rb`

3. Update `solo.json` run-list:
   ```json
   "run_list": [
     "recipe[base::packages]",
     "recipe[base::users]",
     "recipe[docker::install]",
     "recipe[python::install]",
     "recipe[mycookbook::default]"
   ]
   ```

## Recipes

### base::packages
- Updates apt cache
- Installs core packages (curl, wget, git, vim, htop, net-tools, build-essential)
- Sets timezone to UTC

### base::users
- Ensures admin user exists
- Creates .ssh directory
- Grants sudo access
- Enables passwordless sudo (optional)

### docker::install
- Installs Docker prerequisites
- Adds Docker GPG key and official repository
- Installs Docker Engine, CLI, and Compose
- Starts and enables Docker service
- Adds specified users to docker group

### python::install
- Installs Python 3 and development packages
- Creates python/pip symbolic links
- Upgrades pip
- Installs pip packages (virtualenv, etc.)

## Troubleshooting

### Chef Solo fails on VM

Check `/var/log/chef-client.log` on the VM:
```bash
ssh ubuntu@vm-ip
sudo tail -f /var/log/chef-client.log
```

### Docker group changes don't take effect immediately

User must log out and back in for group membership to apply. Or:
```bash
newgrp docker
```

### Python version mismatch

Edit `solo.json` to specify Python version, or uncomment the deadsnakes PPA in `cookbooks/python/recipes/install.rb` for newer versions.

## Git Integration

Keep your repo up-to-date on VMs:

```bash
cd /opt/chef-solo && git pull && sudo chef-solo -c solo.rb -j solo.json
```

Or add a cron job to auto-update periodically.

## License

MIT
