function New-PlacementGroup {
<#
.SYNOPSIS
    This function will check for a Azure Storage Account (RightScale Placement Group) in the specified region.  If it does not exist, it will be created.
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER RsCloudName
    RightScale Cloud display_name value.  For example: AzureRM Brazil South
.PARAMETER RsPlacementGroup
    ASM or ARM Placement Group (Storage Account) name
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> New-PlacementGroup -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -RsCloudName "AzureRM East US" -RsPlacementGroupName lampstack1 -LogFile C:\Temp\Log.txt
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
        $RsCloudName,

        [Parameter(Mandatory=$true)]
        [string]
        $RsPlacementGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    $clouds = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index clouds
    $cloud_href = ((($clouds | ConvertFrom-Json) | Where-Object display_name -eq $RsCloudName).links | Where-Object rel -eq self).href
    $cloud_prefix = $RsCloudName.Split(' ')[0]

    if (!$cloud_href) {
        
        $azure_clouds = $clouds | Where-Object name -like "$cloud_prefix*"
        
        if (!$azure_clouds) {
            Write-LogFile -Message "No $cloud_prefix Clouds connected to RightScale Account No. $RsAccountNum" -MessageType "ERROR" -LogFile $LogFile -Verbose
            EXIT 1
        }
        else {
            Write-LogFile -Message "No Cloud matching $RsCloudName found in RightScale Account No. $RsAccountNum" -MessageType "ERROR" -LogFile $LogFile -Verbose
            EXIT 1
        }
       
    }

    $pg_check = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index /api/placement_groups "filter[]=name==$RsPlacementGroupName" "filter[]=cloud_href==$cloud_href"

    if(!($pg_check)) {
        Write-LogFile -Message "Placement Group not found. Creating..." -MessageType "INFO" -LogFile $LogFile -Verbose
        #Create the placement group

        .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 create /api/placement_groups "placement_group[name]=$RsPlacementGroupName" "placement_group[cloud_href]=$cloud_href"

        $pg_confirm = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index /api/placement_groups "filter[]=name==$RsPlacementGroupName" "filter[]=cloud_href==$cloud_href"
        
        if ($pg_confirm) {
            Write-LogFile -Message "Placement Group succesfully created!" -MessageType "INFO" -LogFile $LogFile -Verbose
        } else {
            Write-LogFile -Message "Failed to create Placement Group!" -MessageType "ERROR" -LogFile $LogFile -Verbose
            EXIT 1
        }
    }
    else {
        Write-LogFile -Message "Placement Group already exists!" -MessageType "INFO" -LogFile $LogFile -Verbose
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