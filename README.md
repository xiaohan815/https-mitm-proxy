# HTTPS MITM Proxy

一个通用的 HTTPS 中间人代理工具，可以拦截指定域名的 HTTPS 请求并转发到自定义后端。

## 目录

- [功能特性](#功能特性)
- [工作原理](#工作原理)
- [快速开始](#快速开始)
- [使用场景](#使用场景)
- [跨平台支持](#跨平台支持)
- [配置说明](#配置说明)
- [清理配置](#清理配置)
- [故障排查](#故障排查)

---

## 功能特性

- ✅ 拦截任意 HTTPS 域名
- ✅ 转发到自定义 HTTP/HTTPS 后端
- ✅ 自动生成自签名 CA 证书
- ✅ 自动生成域名证书
- ✅ 支持 HTTP 和 HTTPS 代理
- ✅ 详细的请求日志
- ✅ 跨平台支持 (macOS, Linux, Windows)

---

## 工作原理

```
客户端应用 (Trae IDE)          MITM Proxy                    后端服务 (Ollama)
     │                            │                            │
     │──── HTTPS 请求 ──────────>│                            │
     │   (api.openai.com:443)     │                            │
     │                            │                            │
     │   /etc/hosts 劫持          │                            │
     │   127.0.0.1                │                            │
     │                            │                            │
     │   端口转发 443→8443        │                            │
     │                            │                            │
     │   TLS 握手（自签名证书）    │                            │
     │<──────────────────────────│                            │
     │                            │                            │
     │   解密 HTTPS 请求          │                            │
     │                            │──── HTTP 请求 ──────────>│
     │                            │   (localhost:11434)        │
     │                            │                            │
     │                            │<──── HTTP 响应 ───────────│
     │                            │                            │
     │   加密 HTTPS 响应          │                            │
     │<──────────────────────────│                            │
```

### 技术实现

1. **DNS 劫持**: 修改 hosts 文件，将目标域名解析到本地
2. **端口转发**: 将 443 端口转发到代理服务器端口（8443）
3. **TLS 终止**: 使用自签名证书与客户端建立 HTTPS 连接
4. **协议转换**: 将 HTTPS 请求解密后，用 HTTP 转发到后端
5. **响应加密**: 将后端的 HTTP 响应加密成 HTTPS 返回给客户端

---

## 快速开始

### 支持的平台

| 平台 | 自动化脚本 | 手动配置 |
|------|-----------|---------|
| **macOS** | ✅ | ✅ |
| **Linux** | ✅ | ✅ |
| **Windows** | ✅ | ✅ |

### 1. 安装依赖

```bash
npm install
```

### 2. 配置

编辑 `.env` 文件：

```env
# 要拦截的域名
TARGET_DOMAIN=api.openai.com

# 转发目标（你的后端服务）
BACKEND_URL=http://localhost:11434

# HTTPS 端口（避免需要 root 权限）
HTTPS_PORT=8443
```

### 3. 一键配置系统

#### macOS
```bash
./setup-macos.sh
```

#### Linux
```bash
sudo ./setup-linux.sh
```

#### Windows
```powershell
# 以管理员身份运行 PowerShell
.\setup-windows.ps1
```

**自动完成：**
- ✅ 生成 CA 证书和域名证书
- ✅ 信任 CA 证书到系统
- ✅ 修改 hosts 文件
- ✅ 配置端口转发（443 → 8443）

### 4. 启动代理

```bash
npm start
```

### 5. 测试

```bash
# 测试模型列表
curl https://api.openai.com/v1/models

# 测试聊天
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:7b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

---

## 使用场景

### 场景 1: Trae IDE + Ollama

让 Trae IDE 使用本地 Ollama 模型：

```env
TARGET_DOMAIN=api.openai.com
BACKEND_URL=http://localhost:11434
```

**在 Trae 中配置：**
1. 添加自定义模型
2. 服务商: OpenAI
3. 模型 ID: `qwen2.5:7b`（你 Ollama 中的模型）
4. API Key: 随便填
5. Trae 会认为在访问 OpenAI，实际使用的是本地 Ollama！

### 场景 2: 任意 IDE + 自定义后端

拦截 Claude API 并转发到自定义服务器：

```env
TARGET_DOMAIN=api.anthropic.com
BACKEND_URL=http://192.168.1.100:8000
```

### 场景 3: API 调试

拦截生产 API 请求用于本地调试：

```env
TARGET_DOMAIN=api.example.com
BACKEND_URL=http://localhost:4000
```

---

## 跨平台支持

### macOS

#### 自动配置
```bash
./setup-macos.sh
```

#### 手动配置
```bash
# 1. 修改 hosts
sudo sh -c 'echo "127.0.0.1 api.openai.com" >> /etc/hosts'

# 2. 信任证书
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./certs/ca.crt

# 3. 端口转发（需要编辑 /etc/pf.conf）
echo "rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port 8443" | sudo tee /etc/pf.anchors/mitm-proxy
# 在 /etc/pf.conf 中添加：
#   rdr-anchor "mitm-proxy"
#   load anchor "mitm-proxy" from "/etc/pf.anchors/mitm-proxy"
sudo pfctl -ef /etc/pf.conf
```

---

### Linux

#### 自动配置
```bash
sudo ./setup-linux.sh
```

#### 手动配置（Ubuntu/Debian）
```bash
# 1. 修改 hosts
sudo sh -c 'echo "127.0.0.1 api.openai.com" >> /etc/hosts'

# 2. 信任证书
sudo cp certs/ca.crt /usr/local/share/ca-certificates/mitm-proxy-ca.crt
sudo update-ca-certificates

# 3. 端口转发
sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 8443

# 4. 保存规则（重启后生效）
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

### Windows

#### 自动配置
```powershell
# 以管理员身份运行 PowerShell
.\setup-windows.ps1
```

#### 手动配置
```powershell
# 1. 修改 hosts（以管理员身份）
notepad C:\Windows\System32\drivers\etc\hosts
# 添加: 127.0.0.1 api.openai.com

# 2. 信任证书
# 双击 certs\ca.crt，安装到"受信任的根证书颁发机构"
# 或使用 PowerShell:
Import-Certificate -FilePath "certs\ca.crt" -CertStoreLocation Cert:\LocalMachine\Root

# 3. 端口转发（以管理员身份）
netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=8443 connectaddress=127.0.0.1
```

---

## 配置说明

### 环境变量（.env）

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `PORT` | HTTP 代理端口 | 3001 |
| `HTTPS_PORT` | HTTPS 代理端口 | 8443 |
| `TARGET_DOMAIN` | 要拦截的域名 | api.openai.com |
| `BACKEND_URL` | 转发目标地址 | http://localhost:11434 |
| `ENABLE_HTTPS` | 是否启用 HTTPS | true |
| `CERT_DIR` | 证书存储目录 | ./certs |
| `LOG_LEVEL` | 日志级别 | info |

### 端口说明

- **PORT (3001)**: HTTP 明文代理，用于测试
- **HTTPS_PORT (8443)**: HTTPS 加密代理，避免需要 root 权限
  - 标准 HTTPS 端口是 443，但需要 root/管理员权限
  - 8443 是常见的备用端口，不需要特权
  - 通过端口转发，客户端访问 443 会自动转到 8443

---

## 清理配置

### macOS
```bash
./cleanup-macos.sh
```

### Linux
```bash
sudo ./cleanup-linux.sh
```

### Windows
```powershell
# 以管理员身份运行
.\cleanup-windows.ps1
```

**清理内容：**
- ✅ 删除 CA 证书
- ✅ 清理 hosts 文件
- ✅ 删除端口转发规则
- ✅ 可选删除证书文件

---

## 故障排查

### 问题 1: Connection refused (443 端口)

**原因**: 端口转发未配置或代理未启动

**解决**:
```bash
# 1. 确保代理正在运行
npm start

# 2. 重新配置端口转发
# macOS
./setup-macos.sh

# Linux
sudo ./setup-linux.sh

# Windows
.\setup-windows.ps1
```

---

### 问题 2: 证书不受信任

**原因**: CA 证书未添加到系统信任列表

**解决**:
```bash
# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./certs/ca.crt

# Linux
sudo cp certs/ca.crt /usr/local/share/ca-certificates/mitm-proxy-ca.crt
sudo update-ca-certificates

# Windows
Import-Certificate -FilePath "certs\ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

---

### 问题 3: 无法连接到后端

**原因**: 后端服务未启动或地址错误

**解决**:
```bash
# 检查后端是否运行
curl http://localhost:11434/v1/models

# 如果是 Ollama，启动服务
ollama serve

# 检查 .env 中的 BACKEND_URL 配置
```

---

### 问题 4: POST 请求返回 400

**原因**: 请求体未正确转发（已修复）

**当前版本已解决**，如果仍有问题：
```bash
# 重启代理
npm start
```

---

### 问题 5: hosts 修改不生效

**原因**: DNS 缓存

**解决**:
```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

---

### 问题 6: 请求未被拦截（后端没有收到请求）

**症状**: 应用（如 Trae IDE）请求失败，但代理日志中没有任何请求记录

**常见原因**:
1. 端口转发规则未生效
2. 应用使用 IPv6 连接，但端口转发只配置了 IPv4
3. 应用使用自定义 DNS 或绕过系统代理

**诊断步骤**:
```bash
# 1. 运行自动诊断脚本
./test-connection.sh

# 2. 检查端口转发规则（应该包含 IPv4 和 IPv6）
sudo pfctl -a mitm-proxy -s nat

# 应该看到两条规则：
# rdr pass on lo0 inet proto tcp from any to any port = 443 -> 127.0.0.1 port 8443
# rdr pass on lo0 inet6 proto tcp from any to any port = 443 -> ::1 port 8443

# 3. 测试 IPv4 连接
curl -4 -v https://api.openai.com/v1/models -H "Authorization: Bearer test"

# 4. 测试 IPv6 连接
curl -6 -v https://api.openai.com/v1/models -H "Authorization: Bearer test"

# 5. 查看代理日志
# 如果日志中没有请求记录，说明请求没有到达代理
```

**解决方案**:
```bash
# 重新运行配置脚本（已包含 IPv6 支持）
./setup-macos.sh

# 或手动添加 IPv6 规则
cat << 'EOF' | sudo tee /etc/pf.anchors/mitm-proxy
rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port 8443
rdr pass on lo0 inet6 proto tcp from any to any port 443 -> ::1 port 8443
EOF

# 重新加载 pfctl
sudo pfctl -f /etc/pf.conf
```

**注意**: 如果后端返回 401 错误，这是正常的！说明代理工作正常，只是需要在应用中配置正确的 API Key。

---

### 问题 6: 端口被占用

**原因**: 其他程序占用了端口

**解决**:
```bash
# 修改 .env 中的端口
PORT=3002
HTTPS_PORT=8444

# 或查找并停止占用端口的进程
# macOS/Linux
lsof -i :3001
lsof -i :8443

# Windows
netstat -ano | findstr :3001
```

---

## 验证配置

### 检查 hosts
```bash
# macOS/Linux
cat /etc/hosts | grep api.openai.com

# Windows
type C:\Windows\System32\drivers\etc\hosts | findstr api.openai.com
```

### 检查证书
```bash
# macOS
security find-certificate -c "MITM Proxy CA"

# Linux
ls /usr/local/share/ca-certificates/ | grep mitm

# Windows
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*MITM Proxy CA*" }
```

### 检查端口转发
```bash
# macOS
sudo pfctl -s nat | grep 443

# Linux
sudo iptables -t nat -L OUTPUT -n | grep 443

# Windows
netsh interface portproxy show v4tov4
```

---

## 安全警告

⚠️ **仅用于开发和测试环境！**

- 此工具会拦截 HTTPS 流量，存在安全风险
- 不要在生产环境使用
- 不要用于拦截他人的流量
- 使用完毕后请及时清理配置
- 自签名证书仅用于本地测试

---

## 许可证

MIT

---

## 参考

- [TRAE-Ollama-Bridge](https://github.com/Noyze-AI/TRAE-Ollama-Bridge) - 灵感来源
- [mitmproxy](https://mitmproxy.org/) - MITM 代理参考
- [node-forge](https://github.com/digitalbazaar/forge) - 证书生成库
