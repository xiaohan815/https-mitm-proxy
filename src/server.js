import express from 'express';
import https from 'https';
import http from 'http';
import config from './config.js';
import { initCertificates } from './cert-generator.js';

const app = express();

// 解析 JSON 请求体
app.use(express.json({ limit: '50mb' }));
app.use(express.raw({ type: 'application/octet-stream', limit: '50mb' }));

// 日志中间件
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const targetUrl = `${config.backendUrl}${req.originalUrl}`;
  
  console.log(`\n[${timestamp}] ${req.method} ${req.originalUrl}`);
  console.log(`  From: ${req.headers.host}`);
  console.log(`  To: ${targetUrl}`);
  console.log(`  User-Agent: ${req.headers['user-agent']?.substring(0, 60)}...`);
  
  next();
});

// 代理所有请求
app.all('*', async (req, res) => {
  const targetUrl = `${config.backendUrl}${req.originalUrl}`;
  
  try {
    // 准备请求体
    let body = undefined;
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      if (req.body) {
        // 如果已经被 express.json() 解析
        body = JSON.stringify(req.body);
      } else if (req.rawBody) {
        // 如果是原始数据
        body = req.rawBody;
      }
    }
    
    // 准备请求头
    const headers = {
      ...req.headers,
      host: new URL(config.backendUrl).host,
    };
    
    // 删除可能导致问题的头部
    delete headers['content-length'];
    delete headers['transfer-encoding'];
    
    // 使用 fetch 转发请求
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: headers,
      body: body,
    });
    
    // 复制响应头
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });
    
    // 设置状态码
    res.status(response.status);
    
    // 转发响应体
    const responseBody = await response.text();
    res.send(responseBody);
    
    // 日志
    const statusIcon = response.status >= 200 && response.status < 300 ? '✅' : '❌';
    console.log(`  ${statusIcon} ${response.status} (${responseBody.length} bytes)`);
    
    // 如果是错误，显示响应内容
    if (response.status >= 400) {
      console.log(`  响应: ${responseBody.substring(0, 200)}`);
    }
    console.log('');
    
  } catch (error) {
    console.error(`  ❌ 错误: ${error.message}\n`);
    res.status(502).json({
      error: 'Bad Gateway',
      message: error.message,
      backend: config.backendUrl,
    });
  }
});

// 错误处理
app.use((err, req, res, next) => {
  console.error('❌ 服务器错误:', err.message);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
  });
});

// 启动服务器
function startServer() {
  console.log('\n🚀 HTTPS MITM Proxy 启动中...\n');
  console.log('📋 配置信息:');
  console.log(`   目标域名: ${config.targetDomain}`);
  console.log(`   后端地址: ${config.backendUrl}`);
  console.log(`   HTTP 端口: ${config.port}`);
  
  // HTTP 服务器
  http.createServer(app).listen(config.port, () => {
    console.log(`\n✅ HTTP 服务器运行在: http://localhost:${config.port}`);
  });
  
  // HTTPS 服务器
  if (config.enableHttps) {
    try {
      const credentials = initCertificates();
      console.log(`   HTTPS 端口: ${config.httpsPort}`);
      
      https.createServer(credentials, app).listen(config.httpsPort, () => {
        console.log(`✅ HTTPS 服务器运行在: https://localhost:${config.httpsPort}`);
        console.log('\n📝 使用说明:');
        console.log('   1. 将 CA 证书添加到系统信任列表');
        console.log(`   2. 修改 hosts 文件: 127.0.0.1 ${config.targetDomain}`);
        console.log(`   3. (可选) 端口转发: sudo pfctl 或 iptables 将 443 转发到 ${config.httpsPort}`);
        console.log('\n🧪 测试命令:');
        console.log(`   curl -v https://${config.targetDomain}:${config.httpsPort}/v1/models`);
        console.log(`   curl -v http://localhost:${config.port}/v1/models\n`);
      });
    } catch (error) {
      console.error('❌ HTTPS 服务器启动失败:', error.message);
    }
  }
}

startServer();
