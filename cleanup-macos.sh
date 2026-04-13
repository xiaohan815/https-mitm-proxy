#!/bin/bash

echo "🧹 HTTPS MITM Proxy 完全清理脚本"
echo ""
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

# 读取配置
source .env 2>/dev/null || {
    echo "⚠️  未找到 .env 文件，使用默认值"
    TARGET_DOMAIN="api.openai.com"
}

TARGET_DOMAIN=${TARGET_DOMAIN:-api.openai.com}

# 步骤 1: 删除 CA 证书
echo ""
echo "步骤 1/4: 删除 CA 证书"
if security find-certificate -c "MITM Proxy CA" 2>/dev/null | grep -q "MITM Proxy CA"; then
    echo "正在删除 CA 证书..."
    sudo security delete-certificate -c "MITM Proxy CA" /Library/Keychains/System.keychain 2>/dev/null || true
    echo "✅ CA 证书已删除"
else
    echo "✅ CA 证书不存在（跳过）"
fi

# 步骤 2: 清理 hosts
echo ""
echo "步骤 2/4: 清理 hosts 文件"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    echo "正在删除 hosts 记录..."
    sudo sed -i '' "/$TARGET_DOMAIN/d" /etc/hosts
    echo "✅ hosts 已清理"
else
    echo "✅ hosts 无需清理（跳过）"
fi

# 步骤 3: 删除端口转发
echo ""
echo "步骤 3/4: 删除端口转发规则"

# 禁用 pf
echo "正在禁用 pf..."
sudo pfctl -d 2>/dev/null || true

# 删除规则文件
if [ -f /etc/pf.anchors/mitm-proxy ]; then
    sudo rm /etc/pf.anchors/mitm-proxy
    echo "✅ 规则文件已删除"
fi

# 清理 pf.conf
if grep -q "mitm-proxy" /etc/pf.conf 2>/dev/null; then
    echo "正在清理 pf.conf..."
    sudo cp /etc/pf.conf /etc/pf.conf.backup.cleanup.$(date +%Y%m%d_%H%M%S)
    sudo sed -i '' '/mitm-proxy/d' /etc/pf.conf
    echo "✅ pf.conf 已清理"
fi

# 重新启用 pf
echo "正在重新启用 pf..."
sudo pfctl -ef /etc/pf.conf 2>&1 | grep -v "No ALTQ" | grep -v "ALTQ related" || true
echo "✅ 端口转发已清理"

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

# 完成
echo ""
echo "🎉 清理完成！"
echo ""
echo "📝 如需重新配置，运行: ./setup-all.sh"
