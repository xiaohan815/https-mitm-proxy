#!/bin/bash

echo "🚀 HTTPS MITM Proxy 一键配置脚本"
echo ""
echo "此脚本将完成以下配置："
echo "  1. 生成 CA 和域名证书"
echo "  2. 信任 CA 证书"
echo "  3. 修改 hosts 文件"
echo "  4. 配置端口转发 (443 → 8443)"
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
HTTPS_PORT=${HTTPS_PORT:-8443}

# 步骤 1: 生成证书
echo ""
echo "步骤 1/4: 生成证书"
if [ ! -d "certs" ]; then
    npm run setup > /dev/null 2>&1
    echo "✅ 证书已生成"
else
    echo "✅ 证书已存在（跳过）"
fi

# 步骤 2: 信任 CA 证书
echo ""
echo "步骤 2/4: 信任 CA 证书"
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
echo "步骤 3/4: 修改 hosts 文件"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    echo "✅ hosts 已配置（跳过）"
else
    echo "正在添加 hosts 记录..."
    echo "127.0.0.1 $TARGET_DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo "::1 $TARGET_DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ hosts 已配置"
fi

# 步骤 4: 配置端口转发
echo ""
echo "步骤 4/4: 配置端口转发"

# 创建规则文件（支持 IPv4 和 IPv6）
sudo mkdir -p /etc/pf.anchors
cat << EOF | sudo tee /etc/pf.anchors/mitm-proxy > /dev/null
rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port $HTTPS_PORT
rdr pass on lo0 inet6 proto tcp from any to any port 443 -> ::1 port $HTTPS_PORT
EOF

# 检查 pf.conf
if grep -q "rdr-anchor \"mitm-proxy\"" /etc/pf.conf 2>/dev/null; then
    echo "✅ pf.conf 已配置（跳过）"
else
    echo "正在配置 pf.conf..."
    # 备份
    sudo cp /etc/pf.conf /etc/pf.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    # 在 rdr-anchor "com.apple/*" 之前插入
    sudo awk '
    /^rdr-anchor "com.apple\/\*"/ {
        if (!inserted) {
            print "rdr-anchor \"mitm-proxy\""
            print "load anchor \"mitm-proxy\" from \"/etc/pf.anchors/mitm-proxy\""
            print ""
            inserted = 1
        }
    }
    { print }
    ' /etc/pf.conf | sudo tee /etc/pf.conf.new > /dev/null
    
    sudo mv /etc/pf.conf.new /etc/pf.conf
    echo "✅ pf.conf 已配置"
fi

# 启用 pf
echo "正在启用端口转发..."
sudo pfctl -ef /etc/pf.conf 2>&1 | grep -v "No ALTQ" | grep -v "ALTQ related" | grep -v "Use of -f option" || true
echo "✅ 端口转发已启用"

# 完成
echo ""
echo "🎉 配置完成！"
echo ""
echo "📝 下一步:"
echo "  1. 启动代理: npm start"
echo "  2. 测试: curl https://$TARGET_DOMAIN/v1/models"
echo ""
echo "🧹 如需清理配置，运行: ./cleanup-all.sh"
