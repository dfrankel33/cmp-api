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

$driveLetter = $ENV:DRIVE_LETTER
$drive = $driveLetter+":"

$drives = gwmi Win32_diskdrive
$oldDriveCount = $(if ($drives -is [array]) { $drives.Count } else { 1 }) 

$volumes = gwmi Win32_volume
$oldVolCount = $(if ($volumes -is [array]) { $volumes.Count } else { 1 })

$indexInstance = rsc --rl10 cm15 index_instance_session /api/sessions/instance
$selfHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq self).href

$zoneHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq datacenter).href
write-host "Datacenter href: $zoneHref"

$cloudNum = $selfHref.split("/")[3]
write-host "Cloud Number: $cloudNum"

$instanceID = ($indexInstance | ConvertFrom-Json).resource_uid
write-host "Instance ID: $instanceID"

$volumeName = "vol_$instanceID_$driveLetter"
if ($snapshotid) {
    $indexVolume = rsc --rl10 cm15 index /api/clouds/1/volume_snapshots "filter[]=resource_uid==$ENV:SNAPSHOT_ID"
    write-host "Snapshot href: $snapshotHref"
}

$indexAttachments = rsc --rl10 cm15 index /api/clouds/$cloudNum/volume_attachments "filter[]=instance_href==$selfHref"
$attachmentDevice = (($indexAttachments | convertfrom-json) | where device -eq $device)
if ($attachmentDevice) 
{
    write-host "attachment already exists on $device : $attachmentDevice"
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
    
    "list disk" | diskpart | Write-Host
    "list volume" | diskpart | Write-Host

    write-host "attaching volume..."
    rsc --pp --rl10 cm15 create /api/clouds/$cloudNum/volume_attachments "volume_attachment[instance_href]=$selfHref" "volume_attachment[volume_href]=$volumeHref" "volume_attachment[device]=$device"

    #edit to wait for volume status to equal "in-use"
    start-sleep 300
    "list disk" | diskpart | Write-Host
    "list volume" | diskpart | Write-Host

    $script1 = @"
select disk $oldDriveCount
online disk noerr
attributes disk clear readonly noerr
"@

    $script1 | diskpart | Write-Host

    $script2 = @"
select disk $oldDriveCount
create partition primary noerr
"@

    $script2 | diskpart | Write-Host

    $script3 = @"
select volume $oldVolCount
online volume
attributes volume clear readonly
"@            
            
    $script3 | diskpart | Write-Host

    $script4 = @"
select disk $oldDriveCount
select volume $oldVolCount
format fs=ntfs quick
"@

    $script4 | diskpart | Write-Host


    $volumes = gwmi Win32_volume | where { ($_.BootVolume -ne $True) -and ($_.SystemVolume -ne $True) -and (@(2,5) -notcontains $_.DriveType) -and ($_.Capacity -ge 1000mb)}
    foreach ($volume in $volumes)
    {
        if (!$volume.DriveLetter)
        {
            Write-host "Found volume with no drive letter assigned:"
            Write-host $volume
            Write-Host "Mounting volume $($volume.DeviceID) as $drive"
            mountvol $drive $volume.DeviceID
            $volumeMounted = $True
            break
        }
    }
        
    if ($volumeMounted)
    {
        if (!(Test-Path "${driveLetter}:\"))
        {
            #set-partition -disknumber $oldDriveCount -partitionnumber $oldVolCount -NewDriveLetter $ENV:DRIVE_LETTER
            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root "${driveLetter}:\" -Scope Global
        }
    }
    else
    {
        Write-Host "Volume not found - sleeping for 10 seconds..."
        Start-Sleep -s 10
    }
}

else {
    write-host "volume already exists!"
}