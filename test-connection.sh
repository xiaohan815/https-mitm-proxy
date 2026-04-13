#!/bin/bash

echo "🧪 HTTPS MITM Proxy 连接测试"
echo ""

# 读取配置
source .env 2>/dev/null || {
    echo "❌ 未找到 .env 文件"
    exit 1
}

TARGET_DOMAIN=${TARGET_DOMAIN:-api.openai.com}
HTTPS_PORT=${HTTPS_PORT:-8443}

echo "📋 测试配置:"
echo "  目标域名: $TARGET_DOMAIN"
echo "  HTTPS 端口: $HTTPS_PORT"
echo "  后端地址: $BACKEND_URL"
echo ""

# 测试 1: DNS 解析
echo "测试 1/6: DNS 解析"
if grep -q "$TARGET_DOMAIN" /etc/hosts 2>/dev/null; then
    echo "  ✅ hosts 文件已配置"
    grep "$TARGET_DOMAIN" /etc/hosts | sed 's/^/    /'
else
    echo "  ❌ hosts 文件未配置"
    exit 1
fi
echo ""

# 测试 2: 证书信任
echo "测试 2/6: CA 证书信任"
if security find-certificate -c "MITM Proxy CA" 2>/dev/null | grep -q "MITM Proxy CA"; then
    echo "  ✅ CA 证书已信任"
else
    echo "  ❌ CA 证书未信任"
    exit 1
fi
echo ""

# 测试 3: 端口转发规则
echo "测试 3/6: 端口转发规则"
if sudo pfctl -a mitm-proxy -s nat 2>/dev/null | grep -q "port = 443"; then
    echo "  ✅ 端口转发规则已配置"
    sudo pfctl -a mitm-proxy -s nat 2>&1 | grep "port = 443" | sed 's/^/    /'
else
    echo "  ❌ 端口转发规则未配置"
    exit 1
fi
echo ""

# 测试 4: 代理服务器运行状态
echo "测试 4/6: 代理服务器状态"
if lsof -i :$HTTPS_PORT 2>/dev/null | grep -q "LISTEN"; then
    echo "  ✅ 代理服务器正在运行 (端口 $HTTPS_PORT)"
    lsof -i :$HTTPS_PORT 2>/dev/null | grep "LISTEN" | sed 's/^/    /'
else
    echo "  ❌ 代理服务器未运行"
    echo "  请运行: npm start"
    exit 1
fi
echo ""

# 测试 5: 后端服务状态
echo "测试 5/6: 后端服务状态"
BACKEND_PORT=$(echo $BACKEND_URL | grep -oE '[0-9]+$')
if lsof -i :$BACKEND_PORT 2>/dev/null | grep -q "LISTEN"; then
    echo "  ✅ 后端服务正在运行 (端口 $BACKEND_PORT)"
    lsof -i :$BACKEND_PORT 2>/dev/null | grep "LISTEN" | head -1 | sed 's/^/    /'
else
    echo "  ⚠️  后端服务未运行 (端口 $BACKEND_PORT)"
    echo "  请确保后端服务已启动"
fi
echo ""

# 测试 6: 实际请求测试
echo "测试 6/6: 实际请求测试"
echo "  测试 IPv4 连接..."
if curl -4 -s -o /dev/null -w "%{http_code}" https://$TARGET_DOMAIN/v1/models -H "Authorization: Bearer test" 2>/dev/null | grep -qE "^(200|401)"; then
    echo "  ✅ IPv4 连接成功"
else
    echo "  ❌ IPv4 连接失败"
fi

echo "  测试 IPv6 连接..."
if curl -6 -s -o /dev/null -w "%{http_code}" https://$TARGET_DOMAIN/v1/models -H "Authorization: Bearer test" 2>/dev/null | grep -qE "^(200|401)"; then
    echo "  ✅ IPv6 连接成功"
else
    echo "  ❌ IPv6 连接失败"
fi
echo ""

# 完成
echo "🎉 测试完成！"
echo ""
echo "📝 如果所有测试都通过，Trae IDE 应该可以正常工作"
echo "   如果 Trae 仍然失败，请检查:"
echo "   1. Trae 是否配置了正确的 API Key"
echo "   2. Trae 是否使用了自定义的 DNS 或代理设置"
echo "   3. 查看代理日志中是否有请求记录"
echo ""
