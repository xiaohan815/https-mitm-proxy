import forge from 'node-forge';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { join } from 'path';
import config from './config.js';

const { pki } = forge;

/**
 * 生成自签名 CA 证书
 */
export function generateCA() {
  console.log('🔐 生成 CA 证书...');
  
  const keys = pki.rsa.generateKeyPair(2048);
  const cert = pki.createCertificate();
  
  cert.publicKey = keys.publicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 10);
  
  const attrs = [
    { name: 'commonName', value: 'MITM Proxy CA' },
    { name: 'countryName', value: 'CN' },
    { name: 'organizationName', value: 'MITM Proxy' },
  ];
  
  cert.setSubject(attrs);
  cert.setIssuer(attrs);
  
  cert.setExtensions([
    {
      name: 'basicConstraints',
      cA: true,
    },
    {
      name: 'keyUsage',
      keyCertSign: true,
      digitalSignature: true,
      keyEncipherment: true,
    },
  ]);
  
  cert.sign(keys.privateKey, forge.md.sha256.create());
  
  return {
    cert: pki.certificateToPem(cert),
    key: pki.privateKeyToPem(keys.privateKey),
    certObj: cert,
    keyObj: keys.privateKey,
  };
}

/**
 * 使用 CA 签发域名证书
 */
export function generateDomainCert(domain, caCert, caKey) {
  console.log(`🔐 为域名 ${domain} 生成证书...`);
  
  const keys = pki.rsa.generateKeyPair(2048);
  const cert = pki.createCertificate();
  
  cert.publicKey = keys.publicKey;
  cert.serialNumber = Date.now().toString();
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);
  
  const attrs = [
    { name: 'commonName', value: domain },
    { name: 'countryName', value: 'CN' },
    { name: 'organizationName', value: 'MITM Proxy' },
  ];
  
  cert.setSubject(attrs);
  cert.setIssuer(caCert.subject.attributes);
  
  cert.setExtensions([
    {
      name: 'basicConstraints',
      cA: false,
    },
    {
      name: 'keyUsage',
      digitalSignature: true,
      keyEncipherment: true,
    },
    {
      name: 'extKeyUsage',
      serverAuth: true,
      clientAuth: true,
    },
    {
      name: 'subjectAltName',
      altNames: [
        { type: 2, value: domain },
        { type: 2, value: `*.${domain}` },
      ],
    },
  ]);
  
  cert.sign(caKey, forge.md.sha256.create());
  
  return {
    cert: pki.certificateToPem(cert),
    key: pki.privateKeyToPem(keys.privateKey),
  };
}

/**
 * 初始化证书目录并生成证书
 */
export function initCertificates() {
  const certDir = config.certDir;
  
  if (!existsSync(certDir)) {
    mkdirSync(certDir, { recursive: true });
  }
  
  const caPath = join(certDir, 'ca.crt');
  const caKeyPath = join(certDir, 'ca.key');
  const domainCertPath = join(certDir, `${config.targetDomain}.crt`);
  const domainKeyPath = join(certDir, `${config.targetDomain}.key`);
  
  let ca, caKey;
  
  // 检查 CA 是否已存在
  if (existsSync(caPath) && existsSync(caKeyPath)) {
    console.log('✅ 使用现有 CA 证书');
    const caCertPem = readFileSync(caPath, 'utf-8');
    const caKeyPem = readFileSync(caKeyPath, 'utf-8');
    ca = pki.certificateFromPem(caCertPem);
    caKey = pki.privateKeyFromPem(caKeyPem);
  } else {
    console.log('🆕 生成新的 CA 证书');
    const caData = generateCA();
    writeFileSync(caPath, caData.cert);
    writeFileSync(caKeyPath, caData.key);
    ca = caData.certObj;
    caKey = caData.keyObj;
    
    console.log(`\n⚠️  请将以下 CA 证书添加到系统信任列表：`);
    console.log(`   ${caPath}\n`);
    console.log(`   macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${caPath}`);
    console.log(`   Windows: 双击证书文件，安装到"受信任的根证书颁发机构"\n`);
  }
  
  // 生成域名证书
  if (!existsSync(domainCertPath) || !existsSync(domainKeyPath)) {
    console.log(`🆕 生成域名证书: ${config.targetDomain}`);
    const domainCert = generateDomainCert(config.targetDomain, ca, caKey);
    writeFileSync(domainCertPath, domainCert.cert);
    writeFileSync(domainKeyPath, domainCert.key);
  } else {
    console.log(`✅ 使用现有域名证书: ${config.targetDomain}`);
  }
  
  return {
    cert: readFileSync(domainCertPath, 'utf-8'),
    key: readFileSync(domainKeyPath, 'utf-8'),
  };
}
