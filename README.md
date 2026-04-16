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

# HTTPS 端口（使用标准 443 端口）
HTTPS_PORT=443
```

### 3. 配置系统（仅需证书和 hosts）

#### macOS
```bash
# 生成证书
npm run setup

# 手动配置（或使用简化版脚本）
# 1. 信任 CA 证书
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./certs/ca.crt

# 2. 修改 hosts
sudo sh -c 'echo "127.0.0.1 api.openai.com" >> /etc/hosts'
```

**注意：使用 443 端口不需要配置端口转发！**

### 4. 启动代理（需要 sudo）

```bash
# 方式 1: 使用启动脚本（推荐）
sudo ./start.sh

# 方式 2: 直接使用 npm
sudo npm start

# 方式 3: 使用快捷命令
npm run start:sudo
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

**注意：** 使用 443 端口后，不需要指定端口号，直接使用标准 HTTPS URL 即可。

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
| `HTTPS_PORT` | HTTPS 代理端口 | 443 |
| `TARGET_DOMAIN` | 要拦截的域名 | api.openai.com |
| `BACKEND_URL` | 转发目标地址 | http://localhost:11434 |
| `ENABLE_HTTPS` | 是否启用 HTTPS | true |
| `CERT_DIR` | 证书存储目录 | ./certs |
| `LOG_LEVEL` | 日志级别 | info |
| `ENABLE_HTTP_DEBUG` | 启用 HTTP 调试服务器（可选） | false |

### 端口说明

- **HTTPS_PORT (443)**: HTTPS 标准端口
  - 使用标准端口 443，客户端无需指定端口号
  - **需要 sudo/root 权限启动**（特权端口）
  - **不需要配置端口转发**
  - 启动命令：`sudo npm start` 或 `npm run start:sudo`

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

### 问题 1: Permission denied (EACCES) 绑定 443 端口

**原因**: 443 是特权端口，需要 root 权限

**解决**:
```bash
# 使用 sudo 启动
sudo npm start

# 或使用快捷命令
npm run start:sudo
```

---

### 问题 2: Connection refused

**原因**: 代理未启动或后端服务未运行

**解决**:
```bash
# 1. 确保代理正在运行（需要 sudo）
sudo npm start

# 2. 检查后端服务
curl http://localhost:11434/v1/models

# 如果是 Ollama，启动服务
ollama serve
```

---

### 问题 3: 证书不受信任

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

### 问题 4: 无法连接到后端

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

### 问题 5: POST 请求返回 400

**原因**: 请求体未正确转发（已修复）

**当前版本已解决**，如果仍有问题：
```bash
# 重启代理
npm start
```

---

### 问题 6: hosts 修改不生效

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

### 问题 7: 请求未被拦截（后端没有收到请求）

**症状**: 应用（如 Trae IDE）请求失败，但代理日志中没有任何请求记录

**常见原因**:
1. 代理未以 sudo 权限启动
2. hosts 文件配置错误
3. 应用使用自定义 DNS 或绕过系统代理

**诊断步骤**:
```bash
# 1. 检查代理是否在 443 端口运行
sudo lsof -i :443

# 2. 检查 hosts 文件
cat /etc/hosts | grep api.openai.com

# 3. 测试连接
curl -v https://api.openai.com/v1/models -H "Authorization: Bearer test"

# 4. 查看代理日志
# 如果日志中没有请求记录，说明请求没有到达代理
```

**解决方案**:
```bash
# 1. 确保使用 sudo 启动
sudo npm start

# 2. 检查 hosts 配置
sudo sh -c 'echo "127.0.0.1 api.openai.com" >> /etc/hosts'

# 3. 清除 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

---

### 问题 8: 端口被占用

**原因**: 其他程序占用了端口

**解决**:
```bash
# 查找占用 443 端口的进程
sudo lsof -i :443

# 停止占用端口的进程
sudo kill -9 <PID>
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

### 检查端口监听
```bash
# 检查 443 端口是否被监听
sudo lsof -i :443

# 应该看到 node 进程
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
