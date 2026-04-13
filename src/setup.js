#!/usr/bin/env node
import { execSync } from 'child_process';
import { readFileSync, appendFileSync } from 'fs';
import { join } from 'path';
import config from './config.js';
import { initCertificates } from './cert-generator.js';

console.log('🔧 HTTPS MITM Proxy 设置工具\n');

// 1. 生成证书
console.log('步骤 1: 生成证书');
initCertificates();

// 2. 提示修改 hosts
console.log('\n步骤 2: 修改 hosts 文件');
console.log(`需要将以下内容添加到 hosts 文件:\n`);
console.log(`127.0.0.1 ${config.targetDomain}`);
console.log(`::1 ${config.targetDomain}\n`);

const platform = process.platform;

if (platform === 'darwin') {
  console.log('macOS hosts 文件位置: /etc/hosts');
  console.log('执行命令:');
  console.log(`  sudo sh -c 'echo "127.0.0.1 ${config.targetDomain}" >> /etc/hosts'`);
  console.log(`  sudo sh -c 'echo "::1 ${config.targetDomain}" >> /etc/hosts'`);
  console.log('\n或手动编辑:');
  console.log('  sudo nano /etc/hosts\n');
} else if (platform === 'win32') {
  console.log('Windows hosts 文件位置: C:\\Windows\\System32\\drivers\\etc\\hosts');
  console.log('需要以管理员身份编辑该文件\n');
} else {
  console.log('Linux hosts 文件位置: /etc/hosts');
  console.log('执行命令:');
  console.log(`  sudo sh -c 'echo "127.0.0.1 ${config.targetDomain}" >> /etc/hosts'`);
}

// 3. 端口转发说明
console.log('\n步骤 3: 端口转发 (可选)');
console.log('如果需要拦截标准 HTTPS 端口 (443)，需要配置端口转发:\n');

if (platform === 'darwin') {
  console.log('macOS 使用 pfctl:');
  console.log('  1. 创建转发规则文件 /etc/pf.anchors/mitm-proxy:');
  console.log(`     rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port ${config.httpsPort}`);
  console.log('  2. 编辑 /etc/pf.conf，添加:');
  console.log('     rdr-anchor "mitm-proxy"');
  console.log('     load anchor "mitm-proxy" from "/etc/pf.anchors/mitm-proxy"');
  console.log('  3. 启用规则:');
  console.log('     sudo pfctl -ef /etc/pf.conf\n');
} else if (platform === 'win32') {
  console.log('Windows 使用 netsh:');
  console.log(`  netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=${config.httpsPort} connectaddress=127.0.0.1`);
  console.log('  需要以管理员身份运行命令提示符\n');
} else {
  console.log('Linux 使用 iptables:');
  console.log(`  sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port ${config.httpsPort}`);
  console.log('  或使用 socat:');
  console.log(`  sudo socat TCP-LISTEN:443,fork TCP:127.0.0.1:${config.httpsPort}\n`);
}

// 4. 信任 CA 证书
console.log('\n步骤 4: 信任 CA 证书');
const caPath = join(config.certDir, 'ca.crt');
console.log(`CA 证书位置: ${caPath}\n`);

if (platform === 'darwin') {
  console.log('macOS 信任证书:');
  console.log(`  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${caPath}`);
  console.log('或双击证书文件，在钥匙串访问中设置为"始终信任"\n');
} else if (platform === 'win32') {
  console.log('Windows 信任证书:');
  console.log('  1. 双击 ca.crt 文件');
  console.log('  2. 点击"安装证书"');
  console.log('  3. 选择"本地计算机"');
  console.log('  4. 选择"将所有的证书都放入下列存储"');
  console.log('  5. 浏览并选择"受信任的根证书颁发机构"\n');
} else {
  console.log('Linux 信任证书:');
  console.log(`  sudo cp ${caPath} /usr/local/share/ca-certificates/mitm-proxy-ca.crt`);
  console.log('  sudo update-ca-certificates\n');
}

console.log('✅ 设置完成！运行 npm start 启动代理服务器\n');
