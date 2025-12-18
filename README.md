# MediaMTX Azure Deployment

Deploy a MediaMTX streaming server to Azure Container Instances to receive streams from your RTSPconvertTest project and serve them to your website.

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed ([Download](https://aka.ms/installazurecliwindows))
- Active Azure subscription
- Resource group in Azure (or script will create one)

### Deployment

**Windows (PowerShell):**
```powershell
.\deploy.ps1 -ResourceGroupName "your-rg-name" -Location "eastus"
```

**Linux/Mac:**
```bash
chmod +x deploy.sh
./deploy.sh your-rg-name eastus
```

## 📋 What Gets Deployed

- **Azure Container Instance** running MediaMTX server
- **Public IP address** with DNS name
- **Open ports:**
  - 8554 (RTSP)
  - 1935 (RTMP)
  - 8888 (HLS)
  - 8889 (WebRTC)
  - 9997 (API)
  - 8000-8001 (UDP for RTP/RTCP)

## 🎥 Usage

### 1. Publish Stream from RTSPconvertTest
After deployment, use the RTSP URL provided to publish your stream:
```
rtsp://your-server.region.azurecontainer.io:8554/live
```

### 2. Consume in Your Website
Use HLS for web playback (compatible with most browsers):
```html
<video id="video" controls></video>
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
<script>
  const video = document.getElementById('video');
  const hls = new Hls();
  hls.loadSource('http://your-server.region.azurecontainer.io:8888/live/index.m3u8');
  hls.attachMedia(video);
</script>
```

## 🔧 Configuration

### MediaMTX Configuration
Edit [mediamtx.yml](mediamtx.yml) to customize:
- Stream paths
- Authentication
- Protocol settings
- Recording options

### Azure Resources
Edit [azure-deploy.parameters.json](azure-deploy.parameters.json) to change:
- Container CPU/Memory
- DNS name label
- Custom Docker image

## 📊 Stream Paths

The server supports multiple paths defined in `mediamtx.yml`:
- `/live` - Main stream from RTSPconvertTest
- `/camera` - Additional camera streams
- `/stream1`, `/stream2` - Custom streams

## 🌐 Protocol Support

| Protocol | Port | URL Pattern | Use Case |
|----------|------|-------------|----------|
| RTSP | 8554 | `rtsp://server:8554/path` | Publishing from cameras/encoders |
| RTMP | 1935 | `rtmp://server:1935/path` | Publishing from OBS, FFmpeg |
| HLS | 8888 | `http://server:8888/path/index.m3u8` | Web playback |
| WebRTC | 8889 | `http://server:8889/path` | Low-latency web playback |

## 🔐 Security Considerations

**For production, you should:**
1. Add authentication to MediaMTX (edit `mediamtx.yml`)
2. Use Azure Virtual Network for private communication
3. Enable HTTPS/TLS for web protocols
4. Restrict inbound traffic using Network Security Groups
5. Use Azure Container Apps or AKS for better scaling

### Example: Add Authentication
Edit `mediamtx.yml`:
```yaml
paths:
  live:
    publishUser: publisher
    publishPass: your-secure-password
    readUser: viewer
    readPass: your-viewer-password
```

## 💰 Cost Optimization

Default configuration (2 CPU, 4GB RAM):
- Estimated cost: ~$60-80/month (24/7 running)

To reduce costs:
1. Lower CPU/memory in `azure-deploy.parameters.json`
2. Use Azure Container Apps with scale-to-zero
3. Stop container when not streaming

**Stop container:**
```bash
az container stop --name mediamtx-server --resource-group your-rg-name
```

**Start container:**
```bash
az container start --name mediamtx-server --resource-group your-rg-name
```

## 🔍 Monitoring

### View container logs:
```bash
az container logs --name mediamtx-server --resource-group your-rg-name --follow
```

### Check API status:
```bash
curl http://your-server:9997/v3/paths/list
```

### View metrics:
```bash
curl http://your-server:9998/metrics
```

## 🐛 Troubleshooting

### Can't connect to RTSP
- Check firewall rules in Azure
- Verify the container is running: `az container show --name mediamtx-server --resource-group your-rg-name`
- Check logs for errors

### Stream not playing in browser
- Ensure HLS is enabled in `mediamtx.yml`
- Check CORS settings for WebRTC
- Try different protocols (HLS vs WebRTC)

### High latency
- Use WebRTC instead of HLS
- Reduce `hlsSegmentDuration` in config
- Check network between publisher and server

## 📚 Additional Resources

- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx)
- [Azure Container Instances](https://docs.microsoft.com/azure/container-instances/)
- [HLS.js Documentation](https://github.com/video-dev/hls.js/)

## 🔄 Updating the Deployment

To update configuration:
1. Edit `mediamtx.yml` or `azure-deploy.bicep`
2. Re-run the deployment script
3. Azure will update the container

## 📝 Integration Examples

### Publishing with FFmpeg
```bash
ffmpeg -re -i input.mp4 -c copy -f rtsp rtsp://your-server:8554/live
```

### Publishing with GStreamer
```bash
gst-launch-1.0 videotestsrc ! x264enc ! rtspclientsink location=rtsp://your-server:8554/live
```

### Web Player (HLS)
```html
<!DOCTYPE html>
<html>
<head>
    <title>MediaMTX Stream</title>
</head>
<body>
    <video id="video" controls autoplay width="100%"></video>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <script>
        const video = document.getElementById('video');
        if (Hls.isSupported()) {
            const hls = new Hls();
            hls.loadSource('http://your-server:8888/live/index.m3u8');
            hls.attachMedia(video);
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = 'http://your-server:8888/live/index.m3u8';
        }
    </script>
</body>
</html>
```

## 🏗️ Advanced: Custom Docker Image

To use custom configuration baked into the image:

1. Build the Docker image:
```bash
docker build -t youracr.azurecr.io/mediamtx:latest .
docker push youracr.azurecr.io/mediamtx:latest
```

2. Update `azure-deploy.parameters.json`:
```json
{
  "imageName": {
    "value": "youracr.azurecr.io/mediamtx:latest"
  },
  "acrLoginServer": {
    "value": "youracr.azurecr.io"
  },
  "acrUsername": {
    "value": "your-username"
  }
}
```

3. Deploy with ACR credentials:
```powershell
.\deploy.ps1 -ResourceGroupName "your-rg" -AcrPassword "your-password"
```
