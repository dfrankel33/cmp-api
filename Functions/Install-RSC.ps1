function Install-RSC {	
<#
.SYNOPSIS
    This function will check if the RightScale RSC tool exists in the current path and will download it if not already present.
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Install-RSC -LogFile C:\Temp\Log.txt
.NOTES
    Author: RightScale
    Jan-2017
#>    

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $LogFile
    )

    $functionName = $MyInvocation.InvocationName
    $rscSource = "https://binaries.rightscale.com/rsbin/rsc/v6/rsc-windows-amd64.zip"
    $currentPath = (Get-Item -Path ".\" -Verbose).FullName

    if(Test-Path "$currentPath\rsc.exe") {
        Write-LogFile -Message "RSC is already installed" -MessageType "INFO" -LogFile $LogFile 
    }
    else {
        Write-LogFile -Message "RSC is NOT installed. Installing..." -MessageType "INFO" -LogFile $LogFile
        $wc = New-Object System.Net.Webclient
        $file = $rscSource.split("/")[-1]
        Write-LogFile -Message "Downloading RSC..." -MessageType "INFO" -LogFile $LogFile
        $downloadedFile = "${env:TEMP}\$file"
        if (Test-Path $downloadedFile) {
            Remove-Item $downloadedFile -Force
        }
        $wc.DownloadFile($rscSource,$downloadedFile)

        Expand-ZIPFile –File $downloadedfile –Destination $currentPath
        Move-Item -Path "$currentPath\rsc\rsc.exe" -Destination $currentPath -Force
        Remove-Item -Path "$currentPath\rsc"
        Write-LogFile -Message "RSC downloaded succesfully" -MessageType "INFO" -LogFile $LogFile
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

function Expand-ZIPFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$File, 
        [Parameter(Mandatory=$true)]
        [string]$Destination
        )

    $shell = New-Object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item)
    }
}