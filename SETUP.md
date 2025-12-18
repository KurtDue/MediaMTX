# GitHub Actions Setup

## 1. Initialize Git Repository

```powershell
cd C:\Git\MTXCloud
git init
git add .
git commit -m "Initial commit - MediaMTX Azure deployment"
git branch -M main
git remote add origin https://github.com/KurtDue/MediaMTX.git
git push -u origin main
```

## 2. Create Azure Service Principal

Run this command to create a service principal for GitHub Actions:

```powershell
az ad sp create-for-rbac `
  --name "github-mediamtx-deploy" `
  --role contributor `
  --scopes /subscriptions/8c020b54-b237-4d6e-82ba-190f6a415d1d/resourceGroups/StoreOne `
  --sdk-auth
```

**Copy the entire JSON output** - you'll need it for the next step.

## 3. Configure GitHub Secrets

Go to your GitHub repository:
https://github.com/KurtDue/MediaMTX/settings/secrets/actions

Click **New repository secret** and add:

**Secret Name:** `AZURE_CREDENTIALS`  
**Secret Value:** Paste the entire JSON from step 2

Example JSON format:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "8c020b54-b237-4d6e-82ba-190f6a415d1d",
  "tenantId": "...",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## 4. Enable ACR Integration

Grant the service principal access to your ACR:

```powershell
# Get the service principal ID from step 2 (the "clientId" value)
$SP_ID="<paste-clientId-here>"

az role assignment create `
  --assignee $SP_ID `
  --role AcrPush `
  --scope /subscriptions/8c020b54-b237-4d6e-82ba-190f6a415d1d/resourceGroups/StoreOne/providers/Microsoft.ContainerRegistry/registries/garbagecan
```

## 5. Deploy

After pushing to GitHub, the workflow will automatically:
1. Build the Docker image
2. Push to your ACR (garbagecan.azurecr.io)
3. Deploy to Azure Container Instances
4. Display all the streaming URLs

You can also manually trigger the deployment from:
https://github.com/KurtDue/MediaMTX/actions

## Stream URLs (after deployment)

**SRT Stream (your main use case):**
```
srt://mediamtx-storeone.northeurope.azurecontainer.io:8890?streamid=live
```

**For website playback:**
```
http://mediamtx-storeone.northeurope.azurecontainer.io:8888/live/index.m3u8
```

## Monitoring

View logs from GitHub Actions or:
```powershell
az container logs --resource-group StoreOne --name mediamtx-server --follow
```
