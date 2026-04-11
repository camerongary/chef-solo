#!/usr/bin/env node

const https = require('https');
const { URL } = require('url');

const XAPI_HOST = '192.168.12.3';
const XAPI_PORT = 443;
const XAPI_USER = 'root';
const XAPI_PASS = process.env.XAPI_PASSWORD || '';

const DEBIAN_TEMPLATE_UUID = 'b42331db-96a3-1578-e85c-8c779d3bf280';
const NETWORK_UUID = '19607085-77df-77e7-4620-4dbea5621f25';

const vmName = process.argv[2] || 'chef-solo-vm';
const githubOwner = process.argv[3] || 'camerongary';
const githubRepo = process.argv[4] || 'chef-solo';
const githubBranch = process.argv[5] || 'main';

const cloudInitUrl = `https://raw.githubusercontent.com/${githubOwner}/${githubRepo}/${githubBranch}/cloud-init.sh`;

console.log('XCP-NG VM Provisioner\n====================');
console.log(`VM: ${vmName}`);
console.log(`Cloud-Init: ${cloudInitUrl}\n`);

class XAPIClient {
  constructor(host, port, user, pass) {
    this.host = host;
    this.port = port;
    this.user = user;
    this.pass = pass;
    this.sessionId = null;
  }

  async call(method, params = []) {
    return new Promise((resolve, reject) => {
      const body = this.buildXmlRpc(method, params);
      const options = {
        hostname: this.host,
        port: this.port,
        path: '/',
        method: 'POST',
        headers: {
          'Content-Type': 'text/xml',
          'Content-Length': Buffer.byteLength(body)
        },
        rejectUnauthorized: false
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const result = this.parseXmlRpc(data);
            if (result.fault) {
              reject(new Error(result.fault));
            } else {
              resolve(result.value);
            }
          } catch (e) {
            reject(e);
          }
        });
      });

      req.on('error', reject);
      req.write(body);
      req.end();
    });
  }

  buildXmlRpc(method, params) {
    const paramsXml = params.map(p => {
      if (typeof p === 'string') {
        return `<param><value><string>${this.escape(p)}</string></value></param>`;
      } else if (typeof p === 'object') {
        const members = Object.entries(p).map(([k, v]) => 
          `<member><n>${k}</n><value><string>${this.escape(String(v))}</string></value></member>`
        ).join('');
        return `<param><value><struct>${members}</struct></value></param>`;
      }
      return `<param><value><string>${this.escape(String(p))}</string></value></param>`;
    }).join('');
    
    return `<?xml version="1.0"?><methodCall><methodName>${method}</methodName><params>${paramsXml}</params></methodCall>`;
  }

  parseXmlRpc(xml) {
    // Check for HTML error (500 error)
    if (xml.includes('<html>') || xml.includes('HTTP')) {
      throw new Error(`Server error: ${xml.substring(0, 200)}`);
    }

    // Check for fault
    if (xml.includes('<fault>')) {
      const stringMatch = xml.match(/<string>([^<]+)<\/string>/);
      return { fault: stringMatch ? stringMatch[1] : 'Unknown error' };
    }

    // Parse struct response (Status/Value fields)
    if (xml.includes('<struct>')) {
      const statusMatch = xml.match(/<n>Status<\/n><value>([^<]+)<\/value>/);
      const valueMatch = xml.match(/<n>Value<\/n><value>([^<]+)<\/value>/);
      
      if (statusMatch && statusMatch[1] === 'Success' && valueMatch) {
        return { value: valueMatch[1] };
      }
      if (statusMatch && statusMatch[1] === 'Failure' && valueMatch) {
        throw new Error(`XAPI Failure: ${valueMatch[1]}`);
      }
      if (statusMatch) {
        const msg = valueMatch ? valueMatch[1] : statusMatch[1];
        throw new Error(`XAPI: ${msg}`);
      }
    }

    // Parse simple value response
    const valueMatch = xml.match(/<value>([^<]+)<\/value>/);
    if (valueMatch && valueMatch[1]) {
      return { value: valueMatch[1] };
    }

    throw new Error(`Parse error: ${xml.substring(0, 200)}`);
  }

  escape(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }
}

function fetchUrl(urlString) {
  return new Promise((resolve, reject) => {
    https.get(urlString, (res) => {
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
    if (!XAPI_PASS) throw new Error('XAPI_PASSWORD not set');

    const xapi = new XAPIClient(XAPI_HOST, XAPI_PORT, XAPI_USER, XAPI_PASS);

    console.log('1. Logging in...');
    const sid = await xapi.call('session.login_with_password', [XAPI_USER, XAPI_PASS, '1.0', 'provisioner']);
    console.log(`   ✓ ${sid.substring(0, 20)}...\n`);

    console.log('2. Fetching cloud-init...');
    const script = await fetchUrl(cloudInitUrl);
    console.log(`   ✓ ${script.length} bytes\n`);

    console.log('3. Cloning template...');
    const vm = await xapi.call('VM.clone', [sid, DEBIAN_TEMPLATE_UUID, vmName]);
    console.log(`   ✓ ${vm}\n`);

    console.log('4. Configuring...');
    await xapi.call('VM.set_memory_static_max', [sid, vm, '2147483648']);
    await xapi.call('VM.set_memory_static_min', [sid, vm, '2147483648']);
    await xapi.call('VM.set_VCPUs_max', [sid, vm, '2']);
    await xapi.call('VM.set_VCPUs_at_startup', [sid, vm, '2']);
    console.log('   ✓ 2GB RAM, 2 vCPUs\n');

    console.log('5. Adding network...');
    await xapi.call('VIF.create', [sid, { VM: vm, network: NETWORK_UUID, device: '0', mtu: '1500', other_config: {} }]);
    console.log('   ✓ Network added\n');

    console.log('6. Injecting cloud-init...');
    await xapi.call('VM.set_other_config', [sid, vm, { 'cloud-init': script }]);
    console.log('   ✓ Script injected\n');

    console.log('7. Starting VM...');
    await xapi.call('VM.start', [sid, vm, 'false', 'false']);
    console.log('   ✓ Started\n');

    console.log('✅ Done!\n');
    console.log(`VM: ${vmName}`);
    console.log(`UUID: ${vm}`);
    console.log(`SSH: cameron@<ip> (password: bike2work)`);

  } catch (e) {
    console.error(`\n❌ ${e.message}`);
    process.exit(1);
  }
}

provision();
