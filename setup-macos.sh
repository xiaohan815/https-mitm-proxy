#!/bin/bash

echo "🚀 HTTPS MITM Proxy 一键配置脚本"
echo ""
echo "此脚本将完成以下配置："
echo "  1. 生成 CA 和域名证书"
echo "  2. 信任 CA 证书"
echo "  3. 修改 hosts 文件"
echo ""
echo "⚠️  注意: 使用 443 端口需要 sudo 权限启动代理"
echo ""
read -p "是否继续？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 读取配置
source .env 2>/dev/null || {
    echo "❌ 未找到 .env 文件"
    exit 1
}

TARGET_DOMAIN=${TARGET_DOMAIN:-api.openai.com}

# 步骤 1: 生成证书
echo ""
echo "步骤 1/3: 生成证书"
if [ ! -d "certs" ]; then
    npm run setup > /dev/null 2>&1
    echo "✅ 证书已生成"
else
    echo "✅ 证书已存在（跳过）"
fi

# 步骤 2: 信任 CA 证书
echo ""
echo "步骤 2/3: 信任 CA 证书"
if security find-certificate -c "MITM Proxy CA" 2>/dev/null | grep -q "MITM Proxy CA"; then
    echo "✅ CA 证书已信任（跳过）"
else
    echo "正在添加 CA 证书到系统信任列表..."
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./certs/ca.crt
    if [ $? -eq 0 ]; then
        echo "✅ CA 证书已信任"
    else
        echo "❌ CA 证书信任失败"
        exit 1
    fi
fi

# 步骤 3: 修改 hosts
echo ""
echo "步骤 3/3: 修改 hosts 文件"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    echo "✅ hosts 已配置（跳过）"
else
    echo "正在添加 hosts 记录..."
    echo "127.0.0.1 $TARGET_DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ hosts 已配置"
fi

# 完成
echo ""
echo "🎉 配置完成！"
echo ""
echo "📝 下一步:"
echo "  1. 启动代理: sudo ./start.sh 或 sudo npm start"
echo "  2. 测试: curl https://$TARGET_DOMAIN/v1/models"
echo ""
echo "🧹 如需清理配置，运行: ./cleanup-macos.sh"
