# MediaMTX Server for Azure Deployment with FFmpeg support
FROM bluenviron/mediamtx:latest-ffmpeg

# Expose necessary ports
# RTSP: 8554 (TCP)
# HLS: 8888 (TCP) - for website playback
# SRT: 8890 (UDP) - for incoming stream
# API: 9997 (TCP) - for monitoring
EXPOSE 8554 8888 8890/udp 9997

# Copy custom configuration
COPY mediamtx.yml /mediamtx.yml

# Run MediaMTX
CMD ["/mediamtx"]
