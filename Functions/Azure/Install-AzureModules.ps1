function Install-AzureModules {
<#
.SYNOPSIS
    This function will check for ASM and ARM PowerShell Modules, and will install them if not already present.  PowerShell version 5 or higher required.
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Install-AzureModules -LogFile C:\Temp\log.txt
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
    $asmModule = Get-Module -Name Azure -ListAvailable
    $armModule = Get-Module -Name AzureRM -ListAvailable

    #ASM
    if($asmModule) {
        Write-LogFile -Message "ASM PowerShell Module is already installed" -MessageType "INFO" -LogFile $LogFile 
    }
    else {
        if(Get-Command -Name "Install-Module") {
            try {
                Write-LogFile -Message "ASM PowerShell Module is NOT installed. Installing..." -MessageType "INFO" -LogFile $LogFile
                Install-Module -Name Azure -Force
                Write-LogFile -Message "ASM PowerShell Module has been installed" -MessageType "INFO" -LogFile $LogFile 
            }
            catch {
                Write-LogFile -Message "$($_.Exception.Message)" -MessageType "ERROR" -LogFile $LogFile
            }
        }
        else {
            #WebPI/MSI based install?
        }
    }

    #ARM
    if($armModule) {
        Write-LogFile -Message "ARM PowerShell Module is already installed" -MessageType "INFO" -LogFile $LogFile
    }
    else {
        if(Get-Command -Name "Install-Module") {
            try {
                Write-LogFile -Message "ARM PowerShell Module is NOT installed. Installing..." -MessageType "INFO" -LogFile $LogFile
                Install-Module -Name AzureRM -Force
                Write-LogFile "ARM PowerShell Module has been installed" -MessageType "INFO" -LogFile $LogFile
            }
            catch {
                Write-LogFile "$($_.Exception.Message)" -MessageType "ERROR" -LogFile $LogFile
            }
        }
        else {
            #WebPI/MSI based install?
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