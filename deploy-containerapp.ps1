# Deploy MediaMTX to Azure Container Apps
# Container Apps has better networking support including UDP

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "northeurope",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "mediamtx-app",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "mediamtx-env",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = "garbagecan"
)

Write-Host "=== Deploying MediaMTX to Azure Container Apps ===" -ForegroundColor Cyan
Write-Host ""

# Get ACR credentials
Write-Host "Getting ACR credentials..." -ForegroundColor Yellow
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv
$acrServer = "$AcrName.azurecr.io"

# Check if Container Apps environment exists
Write-Host "Checking for Container Apps environment..." -ForegroundColor Yellow
$envExists = az containerapp env show --name $EnvironmentName --resource-group $ResourceGroupName 2>$null

if (-not $envExists) {
    Write-Host "Creating Container Apps environment..." -ForegroundColor Yellow
    az containerapp env create `
        --name $EnvironmentName `
        --resource-group $ResourceGroupName `
        --location $Location
}

# Delete existing app if it exists
Write-Host "Removing old app if exists..." -ForegroundColor Yellow
az containerapp delete --name $AppName --resource-group $ResourceGroupName --yes 2>$null

# Create the Container App
Write-Host "Deploying MediaMTX Container App..." -ForegroundColor Cyan
az containerapp create `
    --name $AppName `
    --resource-group $ResourceGroupName `
    --environment $EnvironmentName `
    --image "$acrServer/mediamtx:latest" `
    --registry-server $acrServer `
    --registry-username $AcrName `
    --registry-password $acrPassword `
    --target-port 8554 `
    --ingress external `
    --cpu 2 `
    --memory 4Gi `
    --min-replicas 1 `
    --max-replicas 1

# Get the FQDN
$fqdn = az containerapp show --name $AppName --resource-group $ResourceGroupName --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host ""
Write-Host "=== Deployment Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Container App FQDN: $fqdn" -ForegroundColor White
Write-Host ""
Write-Host "Stream URLs:" -ForegroundColor Cyan
Write-Host "  RTSP:   rtsp://${fqdn}:8554/live" -ForegroundColor White
Write-Host "  HLS:    https://${fqdn}/live/index.m3u8 (port 8888 internally)" -ForegroundColor White
Write-Host "  SRT:    srt://${fqdn}:8890?streamid=live" -ForegroundColor White
Write-Host ""
Write-Host "Note: You may need to configure additional ports in the Azure Portal" -ForegroundColor Yellow
Write-Host "Go to: Portal > Container App > Ingress > Additional Ports" -ForegroundColor Yellow
