# Trae IDE 配置指南

## 问题诊断

### 症状
- Trae IDE 请求失败，显示"模型请求失败"
- 代理后端没有收到任何请求
- 代理日志中没有请求记录

### 根本原因
端口转发规则只配置了 IPv4，但 Trae IDE 可能优先使用 IPv6 连接。

## 解决方案

### 1. 更新端口转发规则（支持 IPv6）

已经为你修复！现在端口转发规则包含 IPv4 和 IPv6：

```bash
# 查看当前规则
sudo pfctl -a mitm-proxy -s nat

# 应该看到：
# rdr pass on lo0 inet proto tcp from any to any port = 443 -> 127.0.0.1 port 8443
# rdr pass on lo0 inet6 proto tcp from any to any port = 443 -> ::1 port 8443
```

### 2. 验证配置

运行自动诊断脚本：

```bash
cd https-mitm-proxy
./test-connection.sh
```

所有测试应该显示 ✅：
- ✅ hosts 文件已配置
- ✅ CA 证书已信任
- ✅ 端口转发规则已配置（IPv4 + IPv6）
- ✅ 代理服务器正在运行
- ✅ 后端服务正在运行
- ✅ IPv4 连接成功
- ✅ IPv6 连接成功

### 3. 配置 Trae IDE

1. 打开 Trae IDE
2. 点击右上角头像 → Settings（设置）
3. 进入 Trae AI → Model Management（模型管理）
4. 点击 Add Model（添加模型）
5. 配置：
   - Provider: OpenAI（或自定义）
   - Base URL: `https://api.openai.com`（保持默认）
   - API Key: 你的后端服务 API Key（例如：`omlxomlx`）
   - Model: 选择你后端支持的模型

### 4. 测试

在 Trae IDE 中发送一个测试请求，你应该能在代理日志中看到：

```
================================================================================
[2026-04-13T10:00:00.000Z] POST /v1/chat/completions
  From: api.openai.com
  To: http://localhost:8000/v1/chat/completions
  User-Agent: ...
  Content-Type: application/json
  Authorization: ✓ Present
  → Forwarding to backend...
  ✅ Response: 200 OK
  Response Size: 1234 bytes
  Backend Time: 500ms
  Total Time: 520ms
================================================================================
```

## 常见问题

### Q1: 仍然看不到请求日志？

**检查清单：**
1. 确认代理服务器正在运行：`lsof -i :8443`
2. 确认 hosts 文件配置正确：`cat /etc/hosts | grep api.openai.com`
3. 确认端口转发规则生效：`sudo pfctl -a mitm-proxy -s nat`
4. 重启 Trae IDE

### Q2: 看到 401 错误？

这是正常的！说明代理工作正常，只是 API Key 不正确。

```bash
# 测试正确的 API Key
curl https://api.openai.com/v1/models -H "Authorization: Bearer omlxomlx"
```

在 Trae IDE 中配置相同的 API Key。

### Q3: 后端服务地址不是 localhost:8000？

修改 `.env` 文件：

```bash
# 编辑配置
nano .env

# 修改 BACKEND_URL
BACKEND_URL=http://your-backend-host:port

# 重启代理
npm start
```

## 技术细节

### 工作原理

```
Trae IDE
  ↓ HTTPS 请求到 api.openai.com:443
  ↓ (DNS: hosts 文件解析到 127.0.0.1 / ::1)
  ↓
pfctl 端口转发
  ↓ IPv4: 443 → 127.0.0.1:8443
  ↓ IPv6: 443 → ::1:8443
  ↓
MITM Proxy (Node.js)
  ↓ TLS 终止（使用自签名证书）
  ↓ HTTPS → HTTP 协议转换
  ↓ 转发请求头和请求体
  ↓
后端服务 (localhost:8000)
  ↓ 处理请求
  ↓ 返回响应
  ↓
MITM Proxy
  ↓ HTTP → HTTPS 协议转换
  ↓ 加密响应
  ↓
Trae IDE
```

### 为什么需要 IPv6 支持？

现代应用（包括 Trae IDE）可能优先使用 IPv6 连接：
- macOS 默认启用 IPv6
- hosts 文件同时配置了 `127.0.0.1` 和 `::1`
- 应用可能优先选择 IPv6 地址

如果端口转发只配置了 IPv4（`inet`），IPv6 连接会直接失败，导致请求无法到达代理。

## 维护

### 查看日志
```bash
# 代理日志会实时显示所有请求
npm start
```

### 重启服务
```bash
# 停止代理（Ctrl+C）
# 重新启动
npm start
```

### 清理配置
```bash
# 完全清理所有配置
./cleanup-macos.sh
```

## 支持

如果问题仍然存在：
1. 运行 `./test-connection.sh` 并提供输出
2. 检查代理日志
3. 检查 Trae IDE 的错误信息
4. 确认后端服务正常运行
