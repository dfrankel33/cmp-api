# This script assumes that rsc.exe is in the working directory
# The output of this script will be:
#   1) All Volume Snapshots whose parent Volume is no longer present
#   2) All Volume Snapshots whose created_at date is older than the input date specified by the user executing this script
#
# AWS Snapshots will include Snapshots that have been SHARED with the AWS Account connected to the target RightScale account.  Use the Cloud_Specific_Attributes field to filter by AWS Account.
# ARM Snapshots likely won't appear in this report unless they meet the age requirement.  This is because: if an ARM volume is deleted after a snapshot has been taken, the volume is still reported as an available resource.

$email = Read-Host "Enter RS email address" # email address associated with RS user
$password = Read-Host "Enter RS Password" # RS password
$endpoint = Read-Host "Enter RS API endpoint (us-3.rightscale.com -or- us-4.rightscale.com)" # us-3.rightscale.com -or- us-4.rightscale.com
$account = Read-Host "Enter RS Account Number" # RS account number

$date = Read-Host "Input date for newest allowed volume snapshots (format: YYYY/MM/DD).  Note: snapshots created on or after this date will not be targeted unless the parent volume no longer exists."

$aws_account = Read-Host "Input AWS Account Number (leave blank if no AWS clouds)"

if ($date.Length -ne 10) {
    Write-Warning "Date value not in correct format. Exiting.."
} else {
    Write-Output "Start time: $(get-date)"
    $my_date = get-date $date
    $clouds = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index clouds | convertfrom-json

    $cloud_hash = @{}
    foreach ($cloud in $clouds) {$cloud_hash.Add($(($cloud.links | where rel -eq self).href), $cloud.display_name)}

    $all_vol = @()
    foreach ($cloud in $clouds) { 
        if ($($cloud.links | where rel -eq volumes)) {
            $vol = @()
            $vol = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index $($cloud.links | where rel -eq volumes).href | ConvertFrom-Json
            $all_vol += $vol 
        }
    }

    $vol_hrefs = @($($all_vol.links | where rel -eq self).href)

    $all_snaps = @()
    [System.Collections.ArrayList]$modified_snaps = @()
    foreach ($cloud in $clouds) {  
        if ($($cloud.links | where rel -eq volume_snapshots)) {
            if (($cloud.display_name -like "AWS*") -and ($aws_account -ne $null)) {
                $snaps = @()
                $snaps = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index $($cloud.links | where rel -eq volume_snapshots).href "filter[]=aws_owner_id==$aws_account" | ConvertFrom-Json
                $all_snaps += $snaps 
                $modified_snaps += $snaps
            } else {
                $snaps = @()
                $snaps = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index $($cloud.links | where rel -eq volume_snapshots).href | ConvertFrom-Json
                $all_snaps += $snaps 
                $modified_snaps += $snaps
            }
        }
    }

    Write-Output "Total Snapshots Discovered: $($all_snaps.Count)"

    $target_snaps = @()
    foreach ($snap in $all_snaps) {
        if ($vol_hrefs -notcontains $($snap.links | where rel -eq parent_volume).href) { 
            $object = $null
            $object = New-Object psobject
            $object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value $cloud_hash.Item($($snap.links | where rel -eq cloud).href)
            $object | Add-Member -MemberType NoteProperty -Name "Name" -Value $snap.name
            $object | Add-Member -MemberType NoteProperty -Name "Resource_UID" -Value $snap.resource_uid 
            $object | Add-Member -MemberType NoteProperty -Name "Size" -Value $snap.size 
            $object | Add-Member -MemberType NoteProperty -Name "Description" -Value $snap.description 
            $object | Add-Member -MemberType NoteProperty -Name "Created_At" -Value $snap.created_at 
            $object | Add-Member -MemberType NoteProperty -Name "Updated_At" -Value $snap.updated_at 
            $object | Add-Member -MemberType NoteProperty -Name "Cloud_Specific_Attributes" -Value $snap.cloud_specific_attributes 
            $object | Add-Member -MemberType NoteProperty -Name "State" -Value $snap.state 
            $target_snaps += $object
            $modified_snaps.Remove($snap)
        }
    }                                              
    #$unattached | Export-Csv ".\$account-unattached-volumes.csv"  
    Write-Output "Snapshots w/o an active Parent Volume: $($target_snaps.Count)"

    $snaps_by_date = 0
    foreach ($snap in $modified_snaps) {
        $snap_date = $null
        $snap_date = get-date $snap.created_at
        if ($snap_date -lt $my_date) {
            $object = $null
            $object = New-Object psobject
            $object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value $cloud_hash.Item($($snap.links | where rel -eq cloud).href)
            $object | Add-Member -MemberType NoteProperty -Name "Name" -Value $snap.name
            $object | Add-Member -MemberType NoteProperty -Name "Resource_UID" -Value $snap.resource_uid 
            $object | Add-Member -MemberType NoteProperty -Name "Size" -Value $snap.size 
            $object | Add-Member -MemberType NoteProperty -Name "Description" -Value $snap.description 
            $object | Add-Member -MemberType NoteProperty -Name "Created_At" -Value $snap.created_at 
            $object | Add-Member -MemberType NoteProperty -Name "Updated_At" -Value $snap.updated_at 
            $object | Add-Member -MemberType NoteProperty -Name "Cloud_Specific_Attributes" -Value $snap.cloud_specific_attributes 
            $object | Add-Member -MemberType NoteProperty -Name "State" -Value $snap.state 
            $target_snaps += $object
            $snaps_by_date++
        }
    }

    Write-Output "Additional snapshots that do not meet the date requirements: $snaps_by_date "

}

$target_snaps | Export-Csv ".\$account-snapshots.csv"

Write-Output "End time: $(get-date)"