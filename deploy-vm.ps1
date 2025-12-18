# Deploy MediaMTX on Azure VM with Docker
# This gives full control over all ports including UDP for SRT

param(
    [string]$ResourceGroupName = "StoreOne",
    [string]$Location = "northeurope",
    [string]$VMName = "mediamtx-vm",
    [string]$VMSize = "Standard_B2s",  # 2 vCPU, 4GB RAM (~$30/month)
    [string]$AdminUsername = "azureuser",
    [string]$DnsLabel = "mediamtx-vm"
)

Write-Host "=== Deploying MediaMTX VM ===" -ForegroundColor Cyan

# Generate SSH key if not exists
$sshKeyPath = "$HOME\.ssh\mediamtx_rsa"
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "Generating SSH key..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -N '""'
}

$sshPublicKey = Get-Content "$sshKeyPath.pub"

# Create VM
Write-Host "Creating VM..." -ForegroundColor Yellow
az vm create `
    --resource-group $ResourceGroupName `
    --name $VMName `
    --location $Location `
    --image Ubuntu2204 `
    --size $VMSize `
    --admin-username $AdminUsername `
    --ssh-key-value "$sshPublicKey" `
    --public-ip-address-dns-name $DnsLabel `
    --nsg-rule SSH

# Open ports for MediaMTX
Write-Host "Opening firewall ports..." -ForegroundColor Yellow
az vm open-port --resource-group $ResourceGroupName --name $VMName --port 8554 --priority 1001  # RTSP
az vm open-port --resource-group $ResourceGroupName --name $VMName --port 8888 --priority 1002  # HLS
az vm open-port --resource-group $ResourceGroupName --name $VMName --port 8890 --priority 1003  # SRT (UDP)
az vm open-port --resource-group $ResourceGroupName --name $VMName --port 9997 --priority 1004  # API

# Get VM details
$vmDetails = az vm show --resource-group $ResourceGroupName --name $VMName --show-details --output json | ConvertFrom-Json
$publicIp = $vmDetails.publicIps
$fqdn = $vmDetails.fqdns

# Get ACR credentials
$acrPassword = az acr credential show --name garbagecan --query "passwords[0].value" -o tsv

# Install Docker and run MediaMTX
Write-Host "Installing Docker and MediaMTX..." -ForegroundColor Cyan
$setupScript = @"
#!/bin/bash
set -e

# Update system
sudo apt-get update
sudo apt-get install -y docker.io

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Login to ACR
echo '$acrPassword' | sudo docker login garbagecan.azurecr.io -u garbagecan --password-stdin

# Run MediaMTX container
sudo docker run -d \
  --name mediamtx \
  --restart unless-stopped \
  -p 8554:8554 \
  -p 8888:8888 \
  -p 8890:8890/udp \
  -p 9997:9997 \
  garbagecan.azurecr.io/mediamtx:latest

echo "MediaMTX container started successfully!"
"@

# Save script to temp file and execute
$setupScript | Out-File -FilePath "$env:TEMP\setup-mediamtx.sh" -Encoding UTF8
scp -i $sshKeyPath -o StrictHostKeyChecking=no "$env:TEMP\setup-mediamtx.sh" "${AdminUsername}@${publicIp}:/tmp/setup.sh"
ssh -i $sshKeyPath -o StrictHostKeyChecking=no "${AdminUsername}@${publicIp}" "chmod +x /tmp/setup.sh && /tmp/setup.sh"

Write-Host ""
Write-Host "=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "VM Details:" -ForegroundColor Cyan
Write-Host "  FQDN: $fqdn" -ForegroundColor White
Write-Host "  Public IP: $publicIp" -ForegroundColor White
Write-Host "  SSH: ssh -i $sshKeyPath ${AdminUsername}@${publicIp}" -ForegroundColor White
Write-Host ""
Write-Host "MediaMTX URLs:" -ForegroundColor Cyan
Write-Host "  SRT Input:  srt://${fqdn}:8890?streamid=live" -ForegroundColor Yellow
Write-Host "  RTSP:       rtsp://${fqdn}:8554/live" -ForegroundColor White
Write-Host "  HLS:        http://${fqdn}:8888/live/index.m3u8" -ForegroundColor Yellow
Write-Host "  API:        http://${fqdn}:9997" -ForegroundColor White
Write-Host ""
Write-Host "Container Management:" -ForegroundColor Cyan
Write-Host "  View logs:    ssh -i $sshKeyPath ${AdminUsername}@${publicIp} 'sudo docker logs mediamtx'" -ForegroundColor White
Write-Host "  Restart:      ssh -i $sshKeyPath ${AdminUsername}@${publicIp} 'sudo docker restart mediamtx'" -ForegroundColor White
Write-Host "  Update image: ssh -i $sshKeyPath ${AdminUsername}@${publicIp} 'sudo docker pull garbagecan.azurecr.io/mediamtx:latest && sudo docker restart mediamtx'" -ForegroundColor White
