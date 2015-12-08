$erroractionpreference = 'stop'
if ($env:SNAPSHOT_ID) 
{
    #optional input 
    $snapshotid = $env:SNAPSHOT_ID 
}
if ($env:DEVICE_NAME) 
{
    #mandatory input
    $device = $env:DEVICE_NAME 
}

$indexInstance = rsc --rl10 cm15 index_instance_session /api/sessions/instance
$selfHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq self).href

$zoneHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq datacenter).href
write-host "Datacenter href: $zoneHref"

$cloudNum = $selfHref.split("/")[3]
write-host "Cloud Number: $cloudNum"

$instanceID = ($indexInstance | ConvertFrom-Json).resource_uid
write-host "Instance ID: $instanceID"

$volumeName = "volume_$instanceID"
if ($snapshotid) {
    $indexVolume = rsc --rl10 cm15 index /api/clouds/1/volume_snapshots "filter[]=resource_uid==$ENV:SNAPSHOT_ID"
    write-host "Snapshot href: $snapshotHref"
}

$indexAttachments = rsc --rl10 cm15 index /api/clouds/$cloudNum/volume_attachments "filter[]=instance_href==$selfHref"
$attachmentDevice = (($indexAttachments | convertfrom-json) | where device -eq $device)
if ($attachmentDevice) 
{
    write-host "attachment: $attachmentDevice"
}
else
{
    write-host "volume attachment not found. creating volume..."
    if ($snapshotid)
    {
        rsc --pp --rl10 cm15 create /api/clouds/$cloudNum/volumes "volume[name]=$volumeName" "volume[size]=$ENV:VOLUME_SIZE" "volume[datacenter_href]=$zoneHref" "volume[parent_volume_snapshot_href]=$snapshotHref"
    }
    else
    {
        rsc --pp --rl10 cm15 create /api/clouds/$cloudNum/volumes "volume[name]=$volumeName" "volume[size]=$ENV:VOLUME_SIZE" "volume[datacenter_href]=$zoneHref"
    }
    
    $indexVolumes = rsc --rl10 cm15 index /api/clouds/1/volumes "filter[]=name==$volumeName"
    $volumeHref = (($indexVolumes | ConvertFrom-Json).Links | where rel -eq self).href
    write-host "Volume Href: $volumeHref"

    $drives = gwmi Win32_diskdrive
    # Need to process single item case because Powershell unrolls single item arrays
    $oldDriveCount = $(if ($drives -is [array]) { $drives.Count } else { 1 }) 

    $volumes = gwmi Win32_volume
    # Need to process single item case because Powershell unrolls single item arrays
    $oldVolCount = $(if ($volumes -is [array]) { $volumes.Count } else { 1 })
    
    Write-Host "Before attachment - disks: ${oldDriveCount}, volumes: ${oldVolCount}"
    "list disk" | diskpart | Write-Host
    "list volume" | diskpart | Write-Host

    write-host "attaching volume..."
    rsc --pp --rl10 cm15 create /api/clouds/$cloudNum/volume_attachments "volume_attachment[instance_href]=$selfHref" "volume_attachment[volume_href]=$volumeHref" "volume_attachment[device]=$device"
}

else {
    write-host "volume already exists!"
}