function Confirm-ServerTemplate {
<#
.SYNOPSIS
    Check if a specific revision of a ServerTemplate is available in a RightScale account
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER RsServerTemplateName
    Name of ServerTemplate to import
.PARAMETER RsServerTemplateRev
    (Optional) Revision of ServerTemplate to import
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Confirm-ServerTemplate -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -RsServerTemplateName "RL10 Linux Load Balancer" -RsServerTemplateRev 32 -LogFile C:\Temp\Log.txt
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
        $RsServerTemplateName,

        [Parameter(Mandatory=$false)]
        [string]
        $RsServerTemplateRev,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Checking for existing ServerTemplate in Account No. $RsAccountNum named $RsServerTemplateName" -MessageType "INFO" -LogFile $LogFile
    
    if ($RsServerTemplateRev -eq "HEAD") { $RsServerTemplateRev = "0" }
    if ($RsServerTemplateRev) {
        $serverTemplates = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum cm15 index server_templates "filter[]=name==$RsServerTemplateName" "filter[]=revision==$RsServerTemplateRev" | convertfrom-json 
    } else {
        $serverTemplates = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum cm15 index server_templates "filter[]=name==$RsServerTemplateName" | convertfrom-json 
    }
    
    if (!$serverTemplates) {
        Write-LogFile -Message "No ServerTemplates named $RsServerTemplateName with Rev $RsServerTemplateRev were found in Account No. $RsAccountNum " -MessageType "WARNING" -LogFile $LogFile
        return $false
    } else {
        Write-LogFile -Message "Found the specified ServerTemplate named $RsServerTemplateName with Rev $RsServerTemplateRev in Account No. $RsAccountNum " -MessageType "INFO" -LogFile $LogFile
        return $true
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