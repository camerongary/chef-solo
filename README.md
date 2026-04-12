# Chef Solo Cookbook for Debian VM Provisioning

Automated infrastructure provisioning using Chef Solo and cloud-init on Debian VMs.

## Quick Start

### Prerequisites
- Debian 11+ VM
- Internet connectivity
- SSH access

### Provisioning a VM

1. **Create a Debian VM** in your hypervisor (XCP-NG, KVM, etc.)

2. **Inject cloud-init script** via user-data:
   ```
   Copy the contents of cloud-init.sh into the VM's user-data field
   ```

3. **Boot the VM** - cloud-init will automatically:
   - Download Chef from Munki server
   - Clone this repository via SSH
   - Run Chef Solo with all cookbooks

4. **SSH into the VM**:
   ```bash
   ssh cameron@<vm-ip>
   ```

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
├── cloud-init.sh               (provisioning entry point)
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
- **Deploy key**: GitHub SSH deploy key (base64-encoded in cloud-init.sh)
- **Munki server**: http://192.168.12.249
- **Admin user**: admin
- **Default user**: cameron

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
