function Publish-CAT {
<#
.SYNOPSIS
    Upload a CAT to RightScale Self-Service.  And optionally publish the CAT to the Self-Service Catalog.
.PARAMETER RsEndpoint
    RightScale API Endpoint. Only valid values are: us-3.rightscale.com OR us-4.rightscale.com 
.PARAMETER RsAccountNum
    RightScale Account Number
.PARAMETER RsEmail
    Email address of RightScale user
.PARAMETER RsPassword
    Password of RightScale user
.PARAMETER Source
    Absolute or relative path to CAT file
.PARAMETER Publish 
    Boolean.  If $true, the CAT will be published to the Self-Service Catalog after being uploaded.
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Publish-CAT -RsEndpoint us-3.rightscale.com -RsAccountNum 123456 -RsEmail john.doe@example.com -RsPassword P@ssw0rd -Source .\Base-Windows.rb -Publish $true -LogFile C:\Temp\Log.txt
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
        $Source,

        [Parameter(Mandatory=$false)]
        [string]
        $Publish,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    $cat = Get-Content $Source
    $cat_name = $cat.Split("`n") | ForEach-Object { if ($_ -like "name*") { Write-Output $_.Split("`"")[1] } }
    Write-LogFile -Message "Uploading CAT - $cat_name" -MessageType "INFO" -LogFile $LogFile
    $cat_check = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss index "/api/designer/collections/$RsAccountNum/templates" "filter[]=name==$cat_name" | ConvertFrom-Json

    if ($cat_check) {
        Write-LogFile -Message "CAT with the same name is already present in Account No. $RsAccountNum" -MessageType "INFO" -LogFile $LogFile
        Write-LogFile -Message "Updating CAT in Self-Service Designer" -MessageType "INFO" -LogFile $LogFile
        .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss update $($cat_check.href) "source=$Source"
    } else {
        Write-LogFile -Message "CAT with the same name not found in Account No. $RsAccountNum" -MessageType "INFO" -LogFile $LogFile
        Write-LogFile -Message "Uploading CAT to Self-Service Designer" -MessageType "INFO" -LogFile $LogFile        
        .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss create "/api/designer/collections/$RsAccountNum/templates" "source=$Source"
    }

    $cat_postcheck = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss index "/api/designer/collections/$RsAccountNum/templates" "filter[]=name==$cat_name" | ConvertFrom-Json
    if ($cat_postcheck) {
        Write-LogFile -Message "CAT upload complete" -MessageType "INFO" -LogFile $LogFile
        Write-LogFile -Message "CAT HREF - $($cat_postcheck.href)" -MessageType "INFO" -LogFile $LogFile
    } else {
        Write-LogFile -Message "CAT upload failed" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    }

    if ($Publish) {
        Write-LogFile -Message "Publish flag set.  Attempting to publish CAT to Self-Service Catalog" -MessageType "INFO" -LogFile $LogFile
        .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss publish $($cat_postcheck.href) "id=$($cat_postcheck.id)"
        $catalog = .\rsc.exe --email $RsEmail --pwd $RsPassword --host $RsEndpoint --account $RsAccountNum ss index "/api/catalog/catalogs/$RsAccountNum/applications" | ConvertFrom-Json
        $application = $catalog | Where-Object name -eq $cat_name
        if ($application) {
            Write-LogFile -Message "CAT successfully published to Self-Service Catalog" -MessageType "INFO" -LogFile $LogFile 
        } else {
            Write-LogFile -Message "Failed to publish CAT to Self-Service Catalog" -MessageType "ERROR" -LogFile $LogFile
            EXIT 1 
        }
    } else {
        Write-LogFile -Message "Publish flag not set.  Will not attempt to publish CAT to Self-Service Catalog" -MessageType "INFO" -LogFile $LogFile
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