function Install-AWSModule {
<#
.SYNOPSIS
    This function will check for the AWS PowerShell Module, and will install it if not already present.  PowerShell version 5 or higher required.
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> Install-AWSModule -LogFile C:\Temp\Log.txt
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
    $awsModuleSource = "http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi"
    $awsModule = Get-Module -Name AWSPowershell -ListAvailable
    
    if($awsModule) {
        Write-LogFile -Message "AWS PowerShell Module is already installed" -MessageType "INFO" -LogFile $LogFile
    }
    else {
        if(Get-Command -Name "Install-Module") {
            try {
                Write-LogFile -Message "AWS PowerShell Module is NOT installed. Installing..." -MessageType "INFO" -LogFile $LogFile
                Install-Module -Name AWSPowerShell -Force
                Write-LogFile -Message "AWS PowerShell Module has been installed" -MessageType "INFO" -LogFile $LogFile 
            }
            catch {
                Write-LogFile -Message "$($_.Exception.Message)" -MessageType "ERROR" -LogFile $LogFile
            }
        }
        else {
            Write-LogFile -Message "Downloading AWS PowerShell Module from $awsModuleSource" -MessageType "INFO" -LogFile $LogFile
            try {
                $msifile = "$env:TEMP\AWSToolsAndSDKForNet.msi"
                Invoke-WebRequest -Uri $awsModuleSource -OutFile $msifile -ErrorAction STOP
                Write-LogFile -Message "Installing AWS PowerShell Module..." -MessageType "INFO" -LogFile $LogFile
                $arguments = @("/i","`"$msiFile`"","/qb","/norestart")
                $process = Start-Process -FilePath msiexec.exe -ArgumentList $arguments -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    Write-LogFile -Message "AWS PowerShell Module has been successfully installed" -MessageType "INFO" -LogFile $LogFile
                }
                else {
                    Write-LogFile -Message "Installer exit code $($process.ExitCode) for file $($msifile)" -MessageType "WARNING" -LogFile $LogFile
                }
            }
            catch {
                Write-LogFile -Message "$($_.Exception.Message)" -MessageType "ERROR" -LogFile $LogFile
            }
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