function New-SshKey {
<#
.SYNOPSIS
    Check for SSH Key in a specific region, and if not present, create it.
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER RsSshKeyName
    Name of SSH Key
.PARAMETER RsCloudName
    RightScale Cloud display_name value.  For example: AWS EU-Frankfurt
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> New-SshKey -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -RsSshKeyName Default -RsCloudName "AWS US-East" -LogFile C:\Temp\Log.txt
.NOTES
    Author: RightScale
    Jan-2017
#>
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $RsEndpoint,

        [Parameter(Mandatory=$true)]
        [string]
        $RsAccountNum,

        [Parameter(Mandatory=$true)]
        [string]
        $RsEmail,

        [Parameter(Mandatory=$true)]
        [string]
        $RsPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $RsSshKeyName,

        [Parameter(Mandatory=$true)]
        [string]
        $RsCloudName,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Checking for existing SSH Key in Account No. $RsAccountNum named $RsSshKeyName in Cloud $RsCloudName" -MessageType "INFO" -LogFile $LogFile

    $clouds = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index clouds | ConvertFrom-Json
    $cloud_href = (($clouds | Where-Object display_name -eq $RsCloudName).links | Where-Object rel -eq self).href

    if (!$cloud_href) {
        $aws_clouds = $clouds | Where-Object name -like "EC2*"
        
        if (!$aws_clouds) {
            Write-LogFile -Message "No AWS Clouds connected to RightScale Account No. $RsAccountNum" -MessageType "ERROR" -LogFile $LogFile
            EXIT 1
        }

        if ($RsCloudName -like "*EC2*") {
            $cloud_search_key = $RsCloudName.Replace("EC2","")
        } else {
            $cloud_search_key = $RsCloudName
        }
        $target_cloud = $aws_clouds | Where-Object display_name -like "*$cloud_search_key*"
        $target_cloud_count = ($target_cloud | Measure-Object).Count
        if ($target_cloud_count -eq 1) {
            $cloud_href = ($target_cloud.links | Where-Object rel -eq self).href
        } else {
            $target_cloud = $aws_clouds | Where-Object name -like "*$cloud_search_key*"
            $target_cloud_count = ($target_cloud | Measure-Object).Count
            if ($target_cloud_count -eq 1) {
                $cloud_href = ($target_cloud.links | Where-Object rel -eq self).href
            } else {
                Write-LogFile -Message "Could not find cloud account using this cloud name: $RsCloudName" -MessageType "ERROR" -LogFile $LogFile
                EXIT 1
            }
        }
    }

    $key_check = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index $cloud_href/ssh_keys "filter[]=name==$RsSshKeyName"

    if (!$key_check) {
        Write-LogFile -Message "SSH Key not found.  Creating new SSH Key" -MessageType "INFO" -LogFile $LogFile
        .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 create $cloud_href/ssh_keys "ssh_key[name]=$RsSshKeyName"

        $key_confirm = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index $cloud_href/ssh_keys "filter[]=name==$RsSshKeyName"
        if ($key_confirm) {
            Write-LogFile -Message "SSH Key successfully created" -MessageType "INFO" -LogFile $LogFile
        } else {
            Write-LogFile -Message "Failed to create SSH Key" -MessageType "ERROR" -LogFile $LogFile
            EXIT 1
        }
    } else {
            Write-LogFile -Message "SSH Key already exists." -MessageType "INFO" -LogFile $LogFile
    }
}

function Write-LogFile {
    [CmdletBinding()]
    Param([string]$Message, [string]$MessageType, [string]$LogFile)

    $source = $((Get-Variable -Scope 1 MyInvocation -ValueOnly).MyCommand.Name)

    $LogMessage = "$(Get-Date -Format s) - $source - $($MessageType.ToUpper()) - $Message"
    
    Write-Verbose $LogMessage

    Add-Content -Path $LogFile -Value $LogMessage
}