#!/bin/bash

echo "🧹 HTTPS MITM Proxy - Linux 清理脚本"
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 读取配置
source .env 2>/dev/null || {
    echo "⚠️  未找到 .env 文件，使用默认值"
    TARGET_DOMAIN="api.openai.com"
    HTTPS_PORT="8443"
}

TARGET_DOMAIN=${TARGET_DOMAIN:-api.openai.com}
HTTPS_PORT=${HTTPS_PORT:-8443}

echo "此脚本将清理以下配置："
echo "  1. 删除 CA 证书"
echo "  2. 清理 hosts 文件"
echo "  3. 删除端口转发规则"
echo "  4. 删除证书文件"
echo ""
read -p "是否继续？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 步骤 1: 删除 CA 证书
echo ""
echo "步骤 1/4: 删除 CA 证书"
if [ -f /usr/local/share/ca-certificates/mitm-proxy-ca.crt ]; then
    rm /usr/local/share/ca-certificates/mitm-proxy-ca.crt
    update-ca-certificates --fresh
    echo "✅ CA 证书已删除"
else
    echo "✅ CA 证书不存在（跳过）"
fi

# 步骤 2: 清理 hosts
echo ""
echo "步骤 2/4: 清理 hosts 文件"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    sed -i "/$TARGET_DOMAIN/d" /etc/hosts
    echo "✅ hosts 已清理"
else
    echo "✅ hosts 无需清理（跳过）"
fi

# 步骤 3: 删除端口转发
echo ""
echo "步骤 3/4: 删除端口转发规则"
if iptables -t nat -L OUTPUT -n | grep -q "REDIRECT.*tcp dpt:443"; then
    # 删除规则：指定完整的规则参数
    iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport 443 -j REDIRECT --to-port $HTTPS_PORT 2>/dev/null || true
    
    # 保存规则
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    echo "✅ 端口转发已清理"
else
    echo "✅ 端口转发无需清理（跳过）"
fi

# 步骤 4: 删除证书文件
echo ""
echo "步骤 4/4: 删除证书文件"
read -p "是否删除证书文件？(y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf certs/
    echo "✅ 证书文件已删除"
else
    echo "⏭️  保留证书文件"
fi

echo ""
echo "🎉 清理完成！"
echo ""
echo "📝 如需重新配置，运行: sudo ./setup-linux.sh"
