function Get-CATHref {
<#
.SYNOPSIS
    Return the HREF value of a CAT by specifying the CAT's name
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER CatName 
    Name of CAT
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Get-CATHref -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -CatName "Base Windows" -LogFile C:\Temp\Log.txt
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
        $CatName,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Verifying that CAT is present" -MessageType "INFO" -LogFile $LogFile
    $cat_check = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss index "/api/designer/collections/$RsAccountNum/templates" "filter[]=name==$CatName" | ConvertFrom-Json  
    if (!$cat_check) {
        Write-LogFile -Message "CAT not present in RS Account $RsAccountNum" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    } else {
        Write-LogFile -Message "Found CAT" -MessageType "INFO" -LogFile $LogFile
        Write-LogFile -Message "CAT HREF - $($cat_check.href) " -MessageType "INFO" -LogFile $LogFile
        return $($cat_check.href)
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