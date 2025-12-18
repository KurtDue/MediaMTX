#!/bin/bash
# Deploy MediaMTX Server to Azure (Linux/Mac version)
# Usage: ./deploy.sh <resource-group-name> [location] [dns-label]

RESOURCE_GROUP=$1
LOCATION=${2:-eastus}
DNS_LABEL=${3:-mediamtx-$RANDOM}

if [ -z "$RESOURCE_GROUP" ]; then
    echo "Usage: ./deploy.sh <resource-group-name> [location] [dns-label]"
    exit 1
fi

echo "=== MediaMTX Azure Deployment ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "DNS Label: $DNS_LABEL"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed"
    exit 1
fi

# Login check
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in. Please login to Azure..."
    az login
fi

# Get current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo "Using subscription: $SUBSCRIPTION"
echo ""

# Check if resource group exists, create if not
echo "Checking resource group..."
if ! az group exists --name $RESOURCE_GROUP --output tsv | grep -q "true"; then
    echo "Creating resource group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location $LOCATION
else
    echo "Resource group exists: $RESOURCE_GROUP"
fi
echo ""

# Deploy using Bicep template
echo "Deploying MediaMTX Container Instance..."
DEPLOYMENT=$(az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file azure-deploy.bicep \
    --parameters dnsNameLabel=$DNS_LABEL \
    --query properties.outputs \
    --output json)

if [ $? -eq 0 ]; then
    echo ""
    echo "=== Deployment Successful! ==="
    echo ""
    
    FQDN=$(echo $DEPLOYMENT | jq -r '.containerFQDN.value')
    IP=$(echo $DEPLOYMENT | jq -r '.containerIPv4Address.value')
    
    echo "Server Details:"
    echo "  FQDN: $FQDN"
    echo "  IP Address: $IP"
    echo ""
    echo "Stream URLs:"
    echo "  RTSP: rtsp://$FQDN:8554/stream"
    echo "  RTMP: rtmp://$FQDN:1935/stream"
    echo "  HLS: http://$FQDN:8888/stream"
    echo "  WebRTC: http://$FQDN:8889/stream"
    echo "  API: http://$FQDN:9997"
    echo ""
    echo "Publishing from RTSPconvertTest:"
    echo "  Use this URL as target: rtsp://$FQDN:8554/live"
    echo ""
    echo "For your website (HLS playback):"
    echo "  HLS Stream: http://$FQDN:8888/live/index.m3u8"
    echo ""
else
    echo "Deployment failed!"
    exit 1
fi
