# Deploy MediaMTX Server to Azure
# Usage: .\deploy.ps1 -ResourceGroupName "your-rg-name" -Location "eastus"

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$DnsNameLabel = "mediamtx-$(Get-Random -Minimum 1000 -Maximum 9999)"
)

Write-Host "=== MediaMTX Azure Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "DNS Label: $DnsNameLabel" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
try {
    az --version | Out-Null
} catch {
    Write-Host "Error: Azure CLI is not installed. Please install it from https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Login check
Write-Host "Checking Azure login status..." -ForegroundColor Cyan
$loginStatus = az account show 2>$null
if (-not $loginStatus) {
    Write-Host "Not logged in. Please login to Azure..." -ForegroundColor Yellow
    az login
}

# Get current subscription
$subscription = az account show --query name -o tsv
Write-Host "Using subscription: $subscription" -ForegroundColor Green
Write-Host ""

# Check if resource group exists, create if not
Write-Host "Checking resource group..." -ForegroundColor Cyan
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
} else {
    Write-Host "Resource group exists: $ResourceGroupName" -ForegroundColor Green
}
Write-Host ""

# Deploy using Bicep template
Write-Host "Deploying MediaMTX Container Instance..." -ForegroundColor Cyan
$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file azure-deploy.bicep `
    --parameters dnsNameLabel=$DnsNameLabel `
    --query properties.outputs `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Deployment Successful! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Server Details:" -ForegroundColor Cyan
    Write-Host "  FQDN: $($deployment.containerFQDN.value)" -ForegroundColor White
    Write-Host "  IP Address: $($deployment.containerIPv4Address.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Stream URLs:" -ForegroundColor Cyan
    Write-Host "  RTSP: $($deployment.rtspUrl.value)/stream" -ForegroundColor White
    Write-Host "  RTMP: $($deployment.rtmpUrl.value)/stream" -ForegroundColor White
    Write-Host "  HLS: $($deployment.hlsUrl.value)/stream" -ForegroundColor White
    Write-Host "  WebRTC: $($deployment.webrtcUrl.value)/stream" -ForegroundColor White
    Write-Host "  API: $($deployment.apiUrl.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Publishing from RTSPconvertTest:" -ForegroundColor Cyan
    Write-Host "  Use this URL as target: rtsp://$($deployment.containerFQDN.value):8554/live" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For your website (HLS playback):" -ForegroundColor Cyan
    Write-Host "  HLS Stream: http://$($deployment.containerFQDN.value):8888/live/index.m3u8" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}
