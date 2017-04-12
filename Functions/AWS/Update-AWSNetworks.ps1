function Update-AWSNetworks {
<#
.SYNOPSIS
    Find AWS VPCs that are currently not named, and rename them with their VPC ID
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Update-AWSNetworks -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -LogFile C:\Temp\Log.txt
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
        $LogFile

    )
    
    $clouds = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index clouds "filter[]=cloud_type==amazon"
    if(!($clouds)) {
        Write-LogFile -Message "No AWS clouds connected!" -MessageType "ERROR" -LogFile $LogFile -Verbose
        EXIT 1
    }
    $aws_clouds = $clouds | ConvertFrom-Json

    foreach($aws_cloud in $aws_clouds) {
        $cloud_href = $aws_cloud.links | Where-Object {$_.rel -eq "self"} | Select-Object -ExpandProperty href
        $networks = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index networks "filter[]=cloud_href==$cloud_href"
        $networks_to_rename = ($networks | ConvertFrom-Json) | Where-Object {$_.name -eq $null}
        
        if($networks_to_rename.cidr_block -ne $null) {
            Write-LogFile -Message "AWS Networks without names have been discovered in $($aws_cloud.display_name)! Renaming..." -MessageType "INFO" -LogFile $LogFile -Verbose
            
            foreach($network in $networks_to_rename) {
                $network_href = ($network.links | Where-Object {$_.rel -eq "self"}).href
                Write-LogFile -Message "Setting the name of $network_href to $($network.resource_uid)" -MessageType "INFO" -LogFile $LogFile -Verbose
                .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 update $network_href "network[name]=$($network.resource_uid)-x"
                .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 update $network_href "network[name]=$($network.resource_uid)"
            }
        }
    
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