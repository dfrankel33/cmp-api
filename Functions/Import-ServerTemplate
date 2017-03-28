function Import-ServerTemplate {
<#
.SYNOPSIS
    Import ServerTemplate from the RightScale MultiCloud Marketplace
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
    C:\PS> Import-ServerTemplate -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -RsServerTemplateName "RL10 Linux Load Balancer" -RsServerTemplateRev 32 -LogFile C:\Temp\Log.txt
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

    #Retreive publication href from Template Name/Rev
    Write-LogFile -Message "Checking for existing Publication in Account No. $RsAccountNum named $RsServerTemplateName with Rev $RsServerTemplateRev" -MessageType "INFO" -LogFile $LogFile
    
    if ($RsServerTemplateRev){
        $publication = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum cm15 index publications "filter[]=name==$RsServerTemplateName" "filter[]=revision==$RsServerTemplateRev" | ConvertFrom-Json
    } else {
        $publications = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum cm15 index publications "filter[]=name==$RsServerTemplateName" | ConvertFrom-Json
        $publication = $publications | Sort-Object "revision" -descending | Select-Object -First 1 
    }
    if (!$publication) {
        Write-LogFile -Message "No Publication named $RsServerTemplateName with Rev $RsServerTemplateRev were found in Account No. $RsAccountNum " -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    } else {
        Write-LogFile -Message "Publication named $($publication.name) with Rev $($publication.revision) found in Account No. $RsAccountNum " -MessageType "INFO" -LogFile $LogFile
        $pub_href = ($publication.links | Where-Object "rel" -eq "self").href
        Write-LogFile -Message "Publication HREF => $pub_href " -MessageType "INFO" -LogFile $LogFile
        Write-LogFile -Message "Importing Publication.." -MessageType "INFO" -LogFile $LogFile
        .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum cm15 import $pub_href
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