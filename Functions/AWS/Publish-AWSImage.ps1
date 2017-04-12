function Publish-AWSImage {
<#
.SYNOPSIS
    This function will share an AWS AMI from one AWS account to another.
.PARAMETER SourceAMI
    Source AMI ID
.PARAMETER SourceRegion
    Region where source AMI exists
.PARAMETER AccountsToGrantAccess
    Destination AWS account numbers
.PARAMETER AWSProfileName
    The name of the AWS Profile added via Set-AWSCredentials
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Publish-AWSImage -SourceAMI ami-123456 -SourceRegion us-east-1 -AccountsToGrantAccess 001234567890 -AWSProfileName MyProfile -LogFile C:\Temp\Log.txt 
.NOTES
    Author: RightScale
    Jan-2017
#>  
    param(
        [Parameter(Mandatory=$true)]
        [String]$SourceAMI,
        [ValidateScript({(Get-AWSRegion).Region -contains $_})] 
        [String]$SourceRegion,
        [Parameter(Mandatory=$true)]
        [String[]]$AccountsToGrantAccess,
        [Parameter(Mandatory=$true)]
        [ValidateScript({(Get-AWSCredentials -ProfileName $_) -ne $null})]
        [String]$AWSProfileName,
        [Parameter(Mandatory=$true)]
        [string]$LogFile
    )

    $SourceAMIObject = Get-EC2Image -Region $SourceRegion -ImageId $SourceAMI -ProfileName $AWSProfileName -ErrorAction SilentlyContinue

    if ($SourceAMIObject){
        foreach($Account in $AccountsToGrantAccess) {
            Write-LogFile -Message "Setting permissions for $Account" -MessageType "INFO" -LogFile $LogFile
            Edit-EC2ImageAttribute -ImageId $SourceAMI -Region $SourceRegion -Attribute launchPermission -OperationType add -UserId $Account -ProfileName $AWSProfileName
        }
    } else {
        Write-LogFile -Message "Invalid source image specified" -MessageType "ERROR" -LogFile $LogFile  
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