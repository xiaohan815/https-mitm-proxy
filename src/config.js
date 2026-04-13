import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 读取 .env 文件
function loadEnv() {
  const envPath = join(__dirname, '../.env');
  try {
    const envContent = readFileSync(envPath, 'utf-8');
    const config = {};
    
    envContent.split('\n').forEach(line => {
      line = line.trim();
      if (line && !line.startsWith('#')) {
        const [key, ...valueParts] = line.split('=');
        const value = valueParts.join('=').trim();
        config[key.trim()] = value;
      }
    });
    
    return config;
  } catch (error) {
    console.warn('⚠️  未找到 .env 文件，使用默认配置');
    return {};
  }
}

const env = loadEnv();

export const config = {
  port: parseInt(env.PORT || '3000'),
  httpsPort: parseInt(env.HTTPS_PORT || '8443'),
  targetDomain: env.TARGET_DOMAIN || 'api.openai.com',
  backendUrl: env.BACKEND_URL || 'http://localhost:11434',
  enableHttps: env.ENABLE_HTTPS === 'true',
  certDir: env.CERT_DIR || './certs',
  logLevel: env.LOG_LEVEL || 'info',
};

export default config;
