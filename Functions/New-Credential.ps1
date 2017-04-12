function New-Credential {
<#
.SYNOPSIS
    Check for and create RightScale Credential
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER RsCredentialName
    Name of RightScale Credential
.PARAMETER RsCredentialValue
    Value of RightScale Credential
.PARAMETER Overwrite
    Boolean.  If $true and the Credential exists, its value will be overwritten
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> New-Credential -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -RsCredentialName WINDOWS_ADMIN_PASSWORD -RsCredentialValue Password1 -Overwrite $true -LogFile C:\Temp\Log.txt
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
        $RsCredentialName,

        [Parameter(Mandatory=$true)]
        [string]
        $RsCredentialValue,

        [Parameter(Mandatory=$false)]
        [bool]
        $Overwrite,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Checking for existing Credential in Account No. $RsAccountNum named: $RsCredentialName" -MessageType "INFO" -LogFile $LogFile

    $cred_check = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index credentials "filter[]=name==$RsCredentialName" | ConvertFrom-Json

    if (!$cred_check) {
        Write-LogFile -Message "Credential not found.  Creating new Credential." -MessageType "INFO" -LogFile $LogFile
        .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 create credentials "credential[name]=$RsCredentialName" "credential[value]=$RsCredentialValue"

        $cred_confirm = .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 index credentials "filter[]=name==$RsCredentialName"
        if ($cred_confirm) {
            Write-LogFile -Message "Credential successfully created" -MessageType "INFO" -LogFile $LogFile
        } else {
            Write-LogFile -Message "Failed to create credential" -MessageType "ERROR" -LogFile $LogFile
            EXIT 1
        }
    } else {
        if ($Overwrite) {
            $cred_href = ($cred_check.links | Where-Object rel -eq "self").href
            Write-LogFile -Message "Updating Credential value" -MessageType "INFO" -LogFile $LogFile
            Write-LogFile -Message "Credential HREF: $cred_href" -MessageType "INFO" -LogFile $LogFile
            .\rsc.exe --host $RsEndpoint --account $RsAccountNum --email $RsEmail --pwd $RsPassword cm15 update $cred_href "credential[value]=$RsCredentialValue"
            Write-LogFile -Message "Credential successfully updated" -MessageType "INFO" -LogFile $LogFile
        } else {
            Write-LogFile -Message "Credential already exists and Overwrite flag is set to false" -MessageType "INFO" -LogFile $LogFile
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