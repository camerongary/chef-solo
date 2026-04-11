#!/usr/bin/env node

/**
 * XCP-NG VM Provisioner
 * Creates Debian VMs with cloud-init from GitHub
 * Uses a wrapper script on the XCP-NG host to avoid SSH execution issues
 */

const { execSync } = require('child_process');
const https = require('https');

const XAPI_HOST = '192.168.12.3';
const XAPI_USER = 'root';
const DEBIAN_TEMPLATE_UUID = 'b42331db-96a3-1578-e85c-8c779d3bf280';
const NETWORK_UUID = '19607085-77df-77e7-4620-4dbea5621f25';

const vmName = process.argv[2] || 'chef-solo-vm';
const githubOwner = process.argv[3] || 'camerongary';
const githubRepo = process.argv[4] || 'chef-solo';
const githubBranch = process.argv[5] || 'main';

const cloudInitUrl = `https://raw.githubusercontent.com/${githubOwner}/${githubRepo}/${githubBranch}/cloud-init.sh`;

console.log('XCP-NG VM Provisioner\n====================');
console.log(`Host: ${XAPI_HOST}\nVM: ${vmName}\n`);

function runRemoteCmd(cmd, desc) {
  console.log(desc);
  try {
    const result = execSync(`ssh ${XAPI_USER}@${XAPI_HOST} "${cmd}"`, 
      { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
    return result.trim();
  } catch (e) {
    throw new Error(`Failed: ${e.message}`);
  }
}

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) resolve(data);
        else reject(new Error(`HTTP ${res.statusCode}`));
      });
    }).on('error', reject);
  });
}

async function provision() {
  try {
    console.log('1. Checking connectivity...');
    runRemoteCmd('xe host-list --minimal | head -c 1', '   ✓');
    console.log('   ✓ Connected\n');

    console.log('2. Verifying cloud-init URL...');
    const script = await fetchUrl(cloudInitUrl);
    console.log(`   ✓ ${script.length} bytes\n`);

    console.log('3. Setting up provisioning script on host...');
    const provisionScript = `#!/bin/bash
set -e
VM_NAME="$1"
GITHUB_URL="$2"
TEMPLATE_UUID="${DEBIAN_TEMPLATE_UUID}"
NETWORK_UUID="${NETWORK_UUID}"

echo "Cloning template..."
UUID=$(xe vm-clone uuid=$TEMPLATE_UUID new-name-label="$VM_NAME")
echo "VM UUID: $UUID"

echo "Configuring..."
xe vm-param-set uuid=$UUID memory-static-max=2147483648
xe vm-param-set uuid=$UUID memory-static-min=2147483648
xe vm-param-set uuid=$UUID VCPUs-max=2
xe vm-param-set uuid=$UUID VCPUs-at-startup=2

echo "Adding network..."
xe vif-create vm-uuid=$UUID network-uuid=$NETWORK_UUID device=1

echo "Injecting cloud-init..."
SCRIPT=$(curl -s "$GITHUB_URL")
xe vm-param-set uuid=$UUID other-config:cloud-init="$SCRIPT"

echo "Starting VM..."
xe vm-start uuid=$UUID

echo "Provisioning complete: $UUID"`;

    // Write script to remote host
    const escapedScript = provisionScript.replace(/'/g, "'\\''");
    runRemoteCmd(`cat > /tmp/provision-vm.sh << 'ENDSCRIPT'\n${provisionScript}\nENDSCRIPT`, '   ✓ Creating');
    runRemoteCmd('chmod +x /tmp/provision-vm.sh', '   ✓ Permissions');
    console.log('   ✓ Script ready\n');

    console.log('4. Running provisioning on XCP-NG host...');
    const result = runRemoteCmd(
      `/tmp/provision-vm.sh "${vmName}" "${cloudInitUrl}"`,
      '   ✓ Provisioning'
    );
    
    // Extract UUID from result
    const uuidMatch = result.match(/VM UUID: ([a-f0-9\-]+)/);
    const uuid = uuidMatch ? uuidMatch[1] : 'unknown';
    console.log(`   ✓ Complete\n`);

    console.log('5. Cleaning up...');
    runRemoteCmd('rm -f /tmp/provision-vm.sh', '   ✓');
    console.log('   ✓ Cleanup done\n');

    console.log('✅ VM Created and Provisioned!\n');
    console.log(`Name: ${vmName}`);
    console.log(`UUID: ${uuid}`);
    console.log(`Memory: 2GB, vCPUs: 2`);
    console.log(`\nCloud-init will run on first boot.`);
    console.log(`SSH: cameron@<ip> (password: bike2work)\n`);

  } catch (error) {
    console.error(`\n❌ ${error.message}`);
    process.exit(1);
  }
}

provision();
