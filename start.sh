#!/bin/bash

echo "🚀 启动 HTTPS MITM Proxy (需要 sudo 权限)"
echo ""

# 检查是否有 sudo 权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 错误: 需要 sudo 权限启动 (443 是特权端口)"
    echo "请使用: sudo ./start.sh"
    exit 1
fi

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
npm start
