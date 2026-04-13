#!/bin/bash

echo "🚀 HTTPS MITM Proxy - Linux 配置脚本"
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 读取配置
source .env 2>/dev/null || {
    echo "❌ 未找到 .env 文件"
    exit 1
}

TARGET_DOMAIN=${TARGET_DOMAIN:-api.openai.com}
HTTPS_PORT=${HTTPS_PORT:-8443}

echo "📋 配置信息:"
echo "   目标域名: $TARGET_DOMAIN"
echo "   HTTPS 端口: $HTTPS_PORT"
echo ""

# 步骤 1: 生成证书
echo "步骤 1/4: 生成证书"
if [ ! -d "certs" ]; then
    sudo -u $SUDO_USER npm run setup > /dev/null 2>&1
    echo "✅ 证书已生成"
else
    echo "✅ 证书已存在（跳过）"
fi

# 步骤 2: 信任 CA 证书
echo ""
echo "步骤 2/4: 信任 CA 证书"
if [ -f /usr/local/share/ca-certificates/mitm-proxy-ca.crt ]; then
    echo "✅ CA 证书已信任（跳过）"
else
    cp certs/ca.crt /usr/local/share/ca-certificates/mitm-proxy-ca.crt
    update-ca-certificates
    echo "✅ CA 证书已信任"
fi

# 步骤 3: 修改 hosts
echo ""
echo "步骤 3/4: 修改 hosts 文件"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    echo "✅ hosts 已配置（跳过）"
else
    echo "127.0.0.1 $TARGET_DOMAIN" >> /etc/hosts
    echo "✅ hosts 已配置"
fi

# 步骤 4: 配置端口转发
echo ""
echo "步骤 4/4: 配置端口转发"

# 检查是否已存在规则
if iptables -t nat -L OUTPUT -n | grep -q "REDIRECT.*tcp dpt:443 redir ports $HTTPS_PORT"; then
    echo "✅ 端口转发已配置（跳过）"
else
    # 添加规则：只重定向本地回环地址的 443 端口
    iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 443 -j REDIRECT --to-port $HTTPS_PORT
    
    # 保存规则（根据发行版不同）
    if command -v netfilter-persistent &> /dev/null; then
        # Debian/Ubuntu
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        # 通用方法
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    echo "✅ 端口转发已配置"
    echo "⚠️  注意: 重启后可能需要重新运行此脚本"
fi

echo ""
echo "🎉 配置完成！"
echo ""
echo "📝 下一步:"
echo "  1. 启动代理: npm start"
echo "  2. 测试: curl https://$TARGET_DOMAIN/v1/models"
echo ""
echo "🧹 如需清理，运行: sudo ./cleanup-linux.sh"
