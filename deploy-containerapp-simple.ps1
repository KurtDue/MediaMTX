# Deploy MediaMTX to Azure Container Apps using YAML config
# This provides more control over port configuration

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "StoreOne",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "northeurope",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "mediamtx",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "mediamtx-env",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = "garbagecan"
)

Write-Host "=== Deploying MediaMTX to Azure Container Apps ===" -ForegroundColor Cyan

# Ensure Container Apps extension is installed
Write-Host "Installing/updating Container Apps extension..." -ForegroundColor Yellow
az extension add --name containerapp --upgrade 2>$null

# Get ACR credentials
Write-Host "Getting ACR credentials..." -ForegroundColor Yellow
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv
$acrServer = "$AcrName.azurecr.io"

# Check if environment exists
Write-Host "Setting up Container Apps environment..." -ForegroundColor Yellow
$envExists = az containerapp env show --name $EnvironmentName --resource-group $ResourceGroupName 2>$null

if (-not $envExists) {
    Write-Host "Creating new environment..." -ForegroundColor Yellow
    az containerapp env create `
        --name $EnvironmentName `
        --resource-group $ResourceGroupName `
        --location $Location
    
    Start-Sleep -Seconds 10
}

# Get environment ID
$envId = az containerapp env show --name $EnvironmentName --resource-group $ResourceGroupName --query "id" -o tsv

# Delete old app if exists
az containerapp delete --name $AppName --resource-group $ResourceGroupName --yes 2>$null
Start-Sleep -Seconds 5

# Create the container app with TCP ingress
Write-Host "Creating Container App..." -ForegroundColor Cyan
az containerapp create `
    --name $AppName `
    --resource-group $ResourceGroupName `
    --environment $EnvironmentName `
    --image "$acrServer/mediamtx:latest" `
    --registry-server $acrServer `
    --registry-username $AcrName `
    --registry-password $acrPassword `
    --target-port 8888 `
    --ingress external `
    --transport tcp `
    --cpu 2.0 `
    --memory 4.0Gi `
    --min-replicas 1 `
    --max-replicas 1

if ($LASTEXITCODE -eq 0) {
    # Get the FQDN
    $fqdn = az containerapp show --name $AppName --resource-group $ResourceGroupName --query "properties.configuration.ingress.fqdn" -o tsv
    
    Write-Host ""
    Write-Host "=== Deployment Successful! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "FQDN: $fqdn" -ForegroundColor White
    Write-Host ""
    Write-Host "📡 Access URLs:" -ForegroundColor Cyan
    Write-Host "  HLS (Website): https://${fqdn}/" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  Additional Configuration Needed:" -ForegroundColor Yellow
    Write-Host "  Container Apps ingress currently exposes one port." -ForegroundColor Yellow
    Write-Host "  For SRT (UDP port 8890), you need to:" -ForegroundColor Yellow
    Write-Host "  1. Go to Azure Portal" -ForegroundColor Yellow
    Write-Host "  2. Open your Container App: $AppName" -ForegroundColor Yellow
    Write-Host "  3. Go to Ingress settings" -ForegroundColor Yellow
    Write-Host "  4. Add additional exposed ports for 8554 (RTSP) and 8890 (SRT)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use Azure Virtual Machine or AKS for full UDP support" -ForegroundColor Yellow
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
}