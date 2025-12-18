# MediaMTX Server for Azure Deployment with FFmpeg support
FROM bluenviron/mediamtx:latest-ffmpeg

# Expose necessary ports
# RTSP: 8554
# RTMP: 1935
# HLS: 8888
# WebRTC: 8889
# SRT: 8890
# API: 9997
EXPOSE 8554 1935 8888 8889 8890 9997 8000/udp 8001/udp

# Copy custom configuration
COPY mediamtx.yml /mediamtx.yml

# Run MediaMTX
CMD ["/mediamtx"]
