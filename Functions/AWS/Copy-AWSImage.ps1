function Copy-AWSImage {
<#
.SYNOPSIS
    This function will copy an AWS AMI across regions and share it across AWS accounts.
.PARAMETER SourceAMI
    Source AMI ID
.PARAMETER SourceRegion
    Region where source AMI exists
.PARAMETER DestinationRegions
    Region where the AMI will be copied to
.PARAMETER AccountsToGrantAccess
    Destination AWS account numbers
.PARAMETER AWSProfileName
    The name of the AWS Profile added via Set-AWSCredentials
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Copy-AWSImage -SourceAMI ami-123456 -SourceRegion us-east-1 -DestinationRegions us-east-2,us-west-1 -Destination-AccountsToGrantAccess 001234567890 -AWSProfileName MyProfile -LogFile C:\Temp\Log.txt 
.NOTES
    Author: RightScale
    Jan-2017
#>  
    param(
        [Parameter(Mandatory=$true)]
        [String]$SourceAMI,
        [ValidateScript({(Get-AWSRegion).Region -contains $_})] 
        [String]$SourceRegion,
        [ValidateScript({(Get-AWSRegion).Region -contains $_})] 
        [String[]]$DestinationRegions,
        [Parameter(Mandatory=$true)]
        [String[]]$AccountsToGrantAccess,
        [Parameter(Mandatory=$true)]
        [ValidateScript({(Get-AWSCredentials -ProfileName $_) -ne $null})]
        [String]$AWSProfileName,
        [Parameter(Mandatory=$true)]
        [string]$LogFile
    )
    
    $functionName = $MyInvocation.InvocationName
    $SourceAMIObject = Get-EC2Image -Region $SourceRegion -ImageId $SourceAMI -ProfileName $AWSProfileName -ErrorAction SilentlyContinue

    if($SourceAMIObject) {
        foreach ($DestinationRegion in $DestinationRegions) {
            Write-LogFile -Message "Copying ${SourceAMI} to ${DestinationRegion}..." -MessageType "INFO" -LogFile $LogFile
            $NewAMI = Copy-EC2Image -SourceImageId $SourceAMI -SourceRegion $SourceRegion -Region $DestinationRegion -ProfileName $AWSProfileName

            if($NewAMI) {
                Write-LogFile -Message "New AMI created in ${DestinationRegion}: $NewAMI" -MessageType "INFO" -LogFile $LogFile
                Write-LogFile -Message "Waiting for copy to complete" -MessageType "INFO" -LogFile $LogFile
                $CopyResult = $null
                while($CopyResult -ne "available") {
                    $CopyResult = (Get-EC2Image -ImageId $NewAMI -Region $DestinationRegion -ProfileName $AWSProfileName).State.Value
                    Start-Sleep -Seconds 15
                }
                Write-LogFile -Message "AMI copied succesfully" -MessageType "INFO" -LogFile $LogFile
                
                if($CopyResult) {
                    foreach($Account in $AccountsToGrantAccess) {
                        Write-LogFile -Message "Setting permissions for $Account" -MessageType "INFO" -LogFile $LogFile
                        Edit-EC2ImageAttribute -ImageId $NewAMI -Region $DestinationRegion -Attribute launchPermission -OperationType add -UserId $Account -ProfileName $AWSProfileName
                    }
                }
                else {
                    Write-LogFile -Message "Error applying permissions" -MessageType "ERROR" -LogFile $LogFile
                    EXIT 1
                }
            }
            else {
                Write-LogFile -Message "Error copying image." -MessageType "ERROR" -LogFile $LogFile
                EXIT 1
            }
        }
    }
    else {
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