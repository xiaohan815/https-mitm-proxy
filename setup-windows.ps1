# HTTPS MITM Proxy - Windows 配置脚本
# 需要以管理员身份运行

Write-Host "🚀 HTTPS MITM Proxy - Windows 配置脚本" -ForegroundColor Green
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ 请以管理员身份运行此脚本" -ForegroundColor Red
    Write-Host "   右键点击 PowerShell，选择'以管理员身份运行'" -ForegroundColor Yellow
    exit 1
}

# 读取配置
$envFile = Get-Content .env -ErrorAction SilentlyContinue
$TARGET_DOMAIN = "api.openai.com"
$HTTPS_PORT = "8443"

foreach ($line in $envFile) {
    if ($line -match "^TARGET_DOMAIN=(.+)$") {
        $TARGET_DOMAIN = $matches[1]
    }
    if ($line -match "^HTTPS_PORT=(.+)$") {
        $HTTPS_PORT = $matches[1]
    }
}

Write-Host "📋 配置信息:"
Write-Host "   目标域名: $TARGET_DOMAIN"
Write-Host "   HTTPS 端口: $HTTPS_PORT"
Write-Host ""

# 步骤 1: 生成证书
Write-Host "步骤 1/4: 生成证书"
if (-not (Test-Path "certs")) {
    npm run setup | Out-Null
    Write-Host "✅ 证书已生成" -ForegroundColor Green
} else {
    Write-Host "✅ 证书已存在（跳过）" -ForegroundColor Green
}

# 步骤 2: 信任 CA 证书
Write-Host ""
Write-Host "步骤 2/4: 信任 CA 证书"
$cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*MITM Proxy CA*" }
if ($cert) {
    Write-Host "✅ CA 证书已信任（跳过）" -ForegroundColor Green
} else {
    $certPath = Resolve-Path "certs\ca.crt"
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host "✅ CA 证书已信任" -ForegroundColor Green
}

# 步骤 3: 修改 hosts
Write-Host ""
Write-Host "步骤 3/4: 修改 hosts 文件"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
if ($hostsContent -match $TARGET_DOMAIN) {
    Write-Host "✅ hosts 已配置（跳过）" -ForegroundColor Green
} else {
    Add-Content -Path $hostsPath -Value "`n127.0.0.1 $TARGET_DOMAIN"
    Write-Host "✅ hosts 已配置" -ForegroundColor Green
}

# 步骤 4: 配置端口转发
Write-Host ""
Write-Host "步骤 4/4: 配置端口转发"
$portProxy = netsh interface portproxy show v4tov4 | Select-String "443"
if ($portProxy) {
    Write-Host "✅ 端口转发已配置（跳过）" -ForegroundColor Green
} else {
    netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=$HTTPS_PORT connectaddress=127.0.0.1 | Out-Null
    Write-Host "✅ 端口转发已配置" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 配置完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📝 下一步:"
Write-Host "  1. 启动代理: npm start"
Write-Host "  2. 测试: curl https://$TARGET_DOMAIN/v1/models"
Write-Host ""
Write-Host "🧹 如需清理，以管理员身份运行: .\cleanup-windows.ps1"
