// Azure Container Instance deployment for MediaMTX Server
param location string = resourceGroup().location
param containerName string = 'mediamtx-server'
param imageName string = 'docker.io/bluenviron/mediamtx:latest'
param dnsNameLabel string = 'mediamtx-${uniqueString(resourceGroup().id)}'
param cpu int = 2
param memoryInGb int = 4

// Container Registry settings (optional - if using custom image)
param acrLoginServer string = ''
param acrUsername string = ''
@secure()
param acrPassword string = ''

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  properties: {
    containers: [
      {
        name: 'mediamtx'
        properties: {
          image: imageName
          ports: [
            {
              port: 8554
              protocol: 'TCP'
            }
            {
              port: 1935
              protocol: 'TCP'
            }
            {
              port: 8888
              protocol: 'TCP'
            }
            {
              port: 8889
              protocol: 'TCP'
            }
            {
              port: 8890
              protocol: 'TCP'
            }
            {
              port: 9997
              protocol: 'TCP'
            }
            {
              port: 8000
              protocol: 'UDP'
            }
            {
              port: 8001
              protocol: 'UDP'
            }
          ]
          resources: {
            requests: {
              cpu: cpu
              memoryInGB: memoryInGb
            }
          }
          environmentVariables: [
            {
              name: 'MTX_LOGLEVEL'
              value: 'info'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          port: 8554
          protocol: 'TCP'
        }
        {
          port: 1935
          protocol: 'TCP'
        }
        {
          port: 8888
          protocol: 'TCP'
        }
        {
          port: 8889
          protocol: 'TCP'
        }
        {
          port: 8890
          protocol: 'TCP'
        }
        {
          port: 9997
          protocol: 'TCP'
        }
        {
          port: 8000
          protocol: 'UDP'
        }
        {
          port: 8001
          protocol: 'UDP'
        }
      ]
    }
    imageRegistryCredentials: empty(acrLoginServer) ? [] : [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
  }
}

output containerFQDN string = containerGroup.properties.ipAddress.fqdn
output containerIPv4Address string = containerGroup.properties.ipAddress.ip
output rtspUrl string = 'rtsp://${containerGroup.properties.ipAddress.fqdn}:8554'
output rtmpUrl string = 'rtmp://${containerGroup.properties.ipAddress.fqdn}:1935'
output hlsUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}:8888'
output webrtcUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}:8889'
output apiUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}:9997'
