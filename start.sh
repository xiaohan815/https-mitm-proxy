#!/bin/bash

echo "🚀 启动 HTTPS MITM Proxy"
echo ""

# 检查配置文件
if [ ! -f .env ]; then
    echo "❌ 错误: 未找到 .env 文件"
    echo "请复制 .env.example 并配置"
    exit 1
fi

# 检查证书
if [ ! -f certs/ca.crt ]; then
    echo "⚠️  未找到证书，正在生成..."
    npm run setup
fi

# 启动服务器
echo "✅ 启动代理服务器..."
echo ""
npm start
