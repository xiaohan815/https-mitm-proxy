# HTTPS MITM Proxy - Windows 配置脚本
# 需要以管理员身份运行

Write-Host "🚀 HTTPS MITM Proxy - Windows 配置脚本" -ForegroundColor Green
Write-Host ""
Write-Host "此脚本将完成以下配置："
Write-Host "  1. 生成 CA 和域名证书"
Write-Host "  2. 信任 CA 证书"
Write-Host "  3. 修改 hosts 文件"
Write-Host ""
Write-Host "⚠️  注意: 使用 443 端口需要管理员权限启动代理" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "是否继续？(y/n)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "已取消"
    exit 0
}

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ 请以管理员身份运行此脚本" -ForegroundColor Red
    Write-Host "   右键点击 PowerShell，选择'以管理员身份运行'" -ForegroundColor Yellow
    exit 1
}

# 读取配置
$envFile = Get-Content .env -ErrorAction SilentlyContinue
if (-not $envFile) {
    Write-Host "❌ 未找到 .env 文件" -ForegroundColor Red
    exit 1
}

$TARGET_DOMAIN = "api.openai.com"

foreach ($line in $envFile) {
    if ($line -match "^TARGET_DOMAIN=(.+)$") {
        $TARGET_DOMAIN = $matches[1]
    }
}

# 步骤 1: 生成证书
Write-Host ""
Write-Host "步骤 1/3: 生成证书"
if (-not (Test-Path "certs")) {
    npm run setup | Out-Null
    Write-Host "✅ 证书已生成" -ForegroundColor Green
} else {
    Write-Host "✅ 证书已存在（跳过）" -ForegroundColor Green
}

# 步骤 2: 信任 CA 证书
Write-Host ""
Write-Host "步骤 2/3: 信任 CA 证书"
$cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*MITM Proxy CA*" }
if ($cert) {
    Write-Host "✅ CA 证书已信任（跳过）" -ForegroundColor Green
} else {
    Write-Host "正在添加 CA 证书到系统信任列表..."
    $certPath = Resolve-Path "certs\ca.crt"
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    if ($?) {
        Write-Host "✅ CA 证书已信任" -ForegroundColor Green
    } else {
        Write-Host "❌ CA 证书信任失败" -ForegroundColor Red
        exit 1
    }
}

# 步骤 3: 修改 hosts
Write-Host ""
Write-Host "步骤 3/3: 修改 hosts 文件"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
if ($hostsContent -match $TARGET_DOMAIN) {
    Write-Host "✅ hosts 已配置（跳过）" -ForegroundColor Green
} else {
    Write-Host "正在添加 hosts 记录..."
    Add-Content -Path $hostsPath -Value "`n127.0.0.1 $TARGET_DOMAIN"
    Write-Host "✅ hosts 已配置" -ForegroundColor Green
}

# 完成
Write-Host ""
Write-Host "🎉 配置完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📝 下一步:"
Write-Host "  1. 以管理员身份启动代理: npm start"
Write-Host "  2. 测试: curl https://$TARGET_DOMAIN/v1/models"
Write-Host ""
Write-Host "🧹 如需清理配置，以管理员身份运行: .\cleanup-windows.ps1"
