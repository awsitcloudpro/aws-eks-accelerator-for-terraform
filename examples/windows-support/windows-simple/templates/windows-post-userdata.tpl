# Vars
$prometheusWindowsExporterVersion = "${prometheus_windows_exporter_version}"
$prometheusWindowsExporterPort = "${prometheus_windows_exporter_port}"

# Prometheus Windows exporter installation
cd $env:Temp
cmd /S /C curl -fsSLO https://github.com/prometheus-community/windows_exporter/releases/download/v$prometheusWindowsExporterVersion/windows_exporter-$prometheusWindowsExporterVersion-amd64.msi
Start-Process msiexec.exe -Wait -ArgumentList "/i windows-exporter-$prometheusWindowsExporterVersion-amd64.msi ENABLED_COLLECTORS=cpu,cs,logical_disk,net,os,system,container,memory /quiet"
# Allow inbound access to Windows exporter from VPC routable CIDR
$mac = Get-EC2InstanceMetadata -Path "/network/interfaces/macs"
$vpcCidrBlock = (Get-EC2InstanceMetadata -Path "/network/interfaces/macs/${mac}vpc-ipv4-cidr-block")
New-NetFirewallRule -DisplayName "Allow inbound access to Windows Exporter from Prometheus EKS pods" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $prometheusWindowsExporterPort -RemoteAddress "$vpcCidrBlock"