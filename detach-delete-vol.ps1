
if ($ENV:DEVICE_NAME) {
    #mandatory parameter
    $device = $ENV:DEVICE_NAME
}

$RIGHTLINK_DIR = 'C:\Program Files\RightScale\RightLink'

$decom_reason = & "${RIGHTLINK_DIR}\rsc.exe" rl10 show /rll/proc/shutdown_kind

If ($decom_reason -eq "terminate")  {
    $driveLetter = $ENV:DRIVE_LETTER

    $indexInstance = rsc --rl10 cm15 index_instance_session /api/sessions/instance
    $selfHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq self).href
    
    $cloudNum = $selfHref.split("/")[3]
    write-host "Cloud Number: $cloudNum"
    
    $instanceID = ($indexInstance | ConvertFrom-Json).resource_uid
    $volumeName = "volume_$instanceID_$driveLetter"
    
    $indexAttachments = rsc --rl10 cm15 index /api/clouds/$cloudNum/volume_attachments "filter[]=instance_href==$selfHref"
    $attachmentDevice = (($indexAttachments | convertfrom-json) | where device -eq $device)
    if ($attachmentDevice) {
        $volume = rsc --rl10 cm15 index /api/clouds/$cloudNum/volumes "filter[]=name==$volumeName"
        
        $attachmentHref = ($attachmentDevice.links | where rel -eq self).href
        write-host "Volume Attachment: $attachmentHref"
        write-host "Detatching volume.."
        rsc --rl10 cm15 destroy $attachmentHref "force=true"
        
        while (((rsc --rl10 cm15 index /api/clouds/$cloudNum/volumes "filter[]=name==$volumeName" | ConvertFrom-Json).status) -ne 'available') {
            write-host "Waiting until volume becomes available for deletion.."
            Start-Sleep 60
            }
        
        $volumeHref = (($volume | ConvertFrom-Json).links | where rel -eq self).href
        write-host "Terminating volume.."
        rsc --rl10 cm15 destroy $volumeHref
    }
}
