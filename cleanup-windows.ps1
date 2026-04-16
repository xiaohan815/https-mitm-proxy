# HTTPS MITM Proxy - Windows 清理脚本
# 需要以管理员身份运行

Write-Host "🧹 HTTPS MITM Proxy - Windows 清理脚本" -ForegroundColor Green
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

foreach ($line in $envFile) {
    if ($line -match "^TARGET_DOMAIN=(.+)$") {
        $TARGET_DOMAIN = $matches[1]
    }
}

Write-Host "此脚本将清理以下配置："
Write-Host "  1. 删除 CA 证书"
Write-Host "  2. 清理 hosts 文件"
Write-Host "  3. 删除证书文件"
Write-Host ""
$confirm = Read-Host "是否继续？(y/n)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "已取消"
    exit 0
}

# 步骤 1: 删除 CA 证书
Write-Host ""
Write-Host "步骤 1/3: 删除 CA 证书"
$cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*MITM Proxy CA*" }
if ($cert) {
    Remove-Item -Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
    Write-Host "✅ CA 证书已删除" -ForegroundColor Green
} else {
    Write-Host "✅ CA 证书不存在（跳过）" -ForegroundColor Green
}

# 步骤 2: 清理 hosts
Write-Host ""
Write-Host "步骤 2/3: 清理 hosts 文件"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
if ($hostsContent -match $TARGET_DOMAIN) {
    $newContent = $hostsContent | Where-Object { $_ -notmatch $TARGET_DOMAIN }
    Set-Content -Path $hostsPath -Value $newContent
    Write-Host "✅ hosts 已清理" -ForegroundColor Green
} else {
    Write-Host "✅ hosts 无需清理（跳过）" -ForegroundColor Green
}

# 步骤 3: 删除证书文件
Write-Host ""
Write-Host "步骤 3/3: 删除证书文件"
$deleteCerts = Read-Host "是否删除证书文件？(y/n)"
if ($deleteCerts -eq "y" -or $deleteCerts -eq "Y") {
    Remove-Item -Path "certs" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ 证书文件已删除" -ForegroundColor Green
} else {
    Write-Host "⏭️  保留证书文件" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 清理完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📝 如需重新配置，以管理员身份运行: .\setup-windows.ps1"
