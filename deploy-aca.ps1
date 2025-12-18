# Deploy MediaMTX to Azure Container Apps
param(
    [string]$ResourceGroupName = "StoreOne",
    [string]$Location = "northeurope",
    [string]$AppName = "mediamtx",
    [string]$EnvironmentName = "mediamtx-env",
    [string]$AcrName = "garbagecan"
)

Write-Host "=== Deploying MediaMTX to Azure Container Apps ===" -ForegroundColor Cyan

# Install extension
az extension add --name containerapp --upgrade 2>$null

# Get ACR credentials
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv
$acrServer = "$AcrName.azurecr.io"

# Create environment if needed
$envExists = az containerapp env show --name $EnvironmentName --resource-group $ResourceGroupName 2>$null
if (-not $envExists) {
    Write-Host "Creating environment..." -ForegroundColor Yellow
    az containerapp env create --name $EnvironmentName --resource-group $ResourceGroupName --location $Location
    Start-Sleep -Seconds 10
}

# Delete old app
az containerapp delete --name $AppName --resource-group $ResourceGroupName --yes 2>$null
Start-Sleep -Seconds 5

# Create app
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
    --transport auto `
    --exposed-port 8890 `
    --cpu 2.0 `
    --memory 4.0Gi `
    --min-replicas 1 `
    --max-replicas 1

if ($LASTEXITCODE -eq 0) {
    $fqdn = az containerapp show --name $AppName --resource-group $ResourceGroupName --query "properties.configuration.ingress.fqdn" -o tsv
    
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "FQDN: $fqdn" -ForegroundColor White
    Write-Host "HLS: https://${fqdn}/" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: May need to configure SRT port 8890 in Portal" -ForegroundColor Yellow
}
