#!/usr/bin/env node
import { execSync } from 'child_process';
import { readFileSync, writeFileSync } from 'fs';
import config from './config.js';

console.log('🧹 HTTPS MITM Proxy 清理工具\n');

const platform = process.platform;

// 1. 清理 hosts 文件
console.log('步骤 1: 清理 hosts 文件');
console.log(`需要从 hosts 文件中删除: ${config.targetDomain}\n`);

if (platform === 'darwin' || platform === 'linux') {
  console.log('执行命令:');
  console.log(`  sudo sed -i '' '/${config.targetDomain}/d' /etc/hosts`);
  console.log('或手动编辑:');
  console.log('  sudo nano /etc/hosts\n');
} else if (platform === 'win32') {
  console.log('手动编辑: C:\\Windows\\System32\\drivers\\etc\\hosts');
  console.log(`删除包含 ${config.targetDomain} 的行\n`);
}

// 2. 清理端口转发
console.log('步骤 2: 清理端口转发\n');

if (platform === 'darwin') {
  console.log('macOS 清理 pfctl 规则:');
  console.log('  sudo pfctl -d  # 禁用 pfctl');
  console.log('  sudo rm /etc/pf.anchors/mitm-proxy');
  console.log('  # 从 /etc/pf.conf 中删除相关行\n');
} else if (platform === 'win32') {
  console.log('Windows 清理 netsh 规则:');
  console.log('  netsh interface portproxy delete v4tov4 listenport=443 listenaddress=0.0.0.0');
  console.log('  需要以管理员身份运行\n');
} else {
  console.log('Linux 清理 iptables 规则:');
  console.log(`  sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -j REDIRECT --to-port ${config.httpsPort}`);
  console.log('  或停止 socat 进程\n');
}

// 3. 删除 CA 证书
console.log('步骤 3: 删除 CA 证书\n');

if (platform === 'darwin') {
  console.log('macOS 删除证书:');
  console.log('  打开"钥匙串访问"应用');
  console.log('  搜索 "MITM Proxy CA"');
  console.log('  右键删除\n');
} else if (platform === 'win32') {
  console.log('Windows 删除证书:');
  console.log('  1. 运行 certmgr.msc');
  console.log('  2. 展开"受信任的根证书颁发机构" > "证书"');
  console.log('  3. 找到 "MITM Proxy CA" 并删除\n');
} else {
  console.log('Linux 删除证书:');
  console.log('  sudo rm /usr/local/share/ca-certificates/mitm-proxy-ca.crt');
  console.log('  sudo update-ca-certificates --fresh\n');
}

console.log('✅ 清理说明完成！请按照上述步骤手动清理\n');
console.log('💡 提示: 证书文件保存在 ./certs 目录，可以手动删除\n');
