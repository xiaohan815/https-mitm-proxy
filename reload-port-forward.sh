#!/bin/bash

echo "🔄 重新加载端口转发规则"
echo ""

# 检查规则文件是否存在
if [ ! -f /etc/pf.anchors/mitm-proxy ]; then
    echo "❌ 端口转发规则文件不存在"
    echo "   请先运行: ./setup-macos.sh"
    exit 1
fi

# 检查 pf.conf 配置
if ! grep -q "mitm-proxy" /etc/pf.conf 2>/dev/null; then
    echo "❌ pf.conf 中未配置 mitm-proxy anchor"
    echo "   请先运行: ./setup-macos.sh"
    exit 1
fi

echo "正在重新加载 pfctl 规则..."
echo ""

# 禁用 pf
sudo pfctl -d 2>&1 | grep -v "ALTQ" || true

# 重新启用 pf 并加载配置
sudo pfctl -ef /etc/pf.conf 2>&1 | grep -v "No ALTQ" | grep -v "ALTQ related" | grep -v "Use of -f option" || true

echo ""
echo "✅ 端口转发规则已重新加载"
echo ""

# 验证规则
echo "📋 当前规则:"
sudo pfctl -a mitm-proxy -s nat 2>&1 | grep -v "ALTQ" | sed 's/^/   /'

echo ""
echo "🧪 测试连接:"
echo "   curl https://api.openai.com/v1/models"
echo ""
