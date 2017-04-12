function Copy-ARMImage {
<#
.SYNOPSIS
    Copy a custom image in ARM between Storage Accounts and across Subscriptions
.PARAMETER AZURE_DESTINATION_SUBSCRIPTION_ID
    Subscription GUID for Destination Subscription
.PARAMETER AZURE_SOURCE_SUBSCRIPTION_ID
    Subscription GUID for Source Subscription
.PARAMETER DESTINATION_STORAGE_ACCOUNT
    Name of the Destination Storage Account
.PARAMETER IMAGE_URI
    Full URI of the source image vhd blob
.PARAMETER AZURE_USERNAME
    Username to authenticate with Azure
.PARAMETER AZURE_PASSWORD
    Password to authenticate with Azure.  This value MUST be a securestring.  For example, you could assign this parameter value to a variable prior to executing this function, like this:  $pass = ConvertTo-SecureString -String "P@ssW0rd1" -AsPlainText -Force
.PARAMETER Wait
    Boolean switch to wait for copy job to complete
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> $secure_string = ConvertTo-SecureString -String "P@ssW0rd1" -AsPlainText -Force
    C:\PS> Copy-ARMImage -AZURE_DESTINATION_SUBSCRIPTION_ID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -AZURE_SOURCE_SUBSCRIPTION_ID yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy -DESTINATION_STORAGE_ACCOUNT storage1 -IMAGE_URI https://rsimages.blob.core.windows.net/system/Microsoft.Compute/Images/vhds/rl10_windows2012R2.vhd -AZURE_USERNAME john.doe@example.com -AZURE_PASSWORD $secure_string -Wait $true -LogFile C:\Temp\Log.txt
.NOTES
    Author: RightScale
    Jan-2017
#>
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $AZURE_DESTINATION_SUBSCRIPTION_ID,

        [Parameter(Mandatory=$true)]
        [string]
        $AZURE_SOURCE_SUBSCRIPTION_ID,

        [Parameter(Mandatory=$true)]
        [string]
        $DESTINATION_STORAGE_ACCOUNT,

        [Parameter(Mandatory=$true)]
        [string]
        $IMAGE_URI,

        [Parameter(Mandatory=$true)]
        [string]
        $AZURE_USERNAME,

        [Parameter(Mandatory=$true)]
        [securestring]
        $AZURE_PASSWORD,

        [Parameter(Mandatory=$false)]
        [bool]
        $Wait,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Starting copy-armimage" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Source Subscription: $AZURE_SOURCE_SUBSCRIPTION_ID" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Destination Subscription: $AZURE_DESTINATION_SUBSCRIPTION_ID" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Source Image: $IMAGE_URI" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Destination Storage Account: $DESTINATION_STORAGE_ACCOUNT" -MessageType "INFO" -LogFile $LogFile
    if ($wait) {
        Write-LogFile -Message "Function will wait for copy to complete before exiting." -MessageType "INFO" -LogFile $LogFile
    } else {
        Write-LogFile -Message "Function will exit prior to copy completing" -MessageType "INFO" -LogFile $LogFile
    }

    #Authenticate with Azure
    $azureCredential = New-Object System.Management.Automation.PSCredential($AZURE_USERNAME, $AZURE_PASSWORD)
    Login-AzureRmAccount -Credential $azureCredential

    #Validate subscriptions
    $subscriptions = Get-AzureRmSubscription

    if ($subscriptions.SubscriptionId -contains $AZURE_SOURCE_SUBSCRIPTION_ID) {
        Write-LogFile -Message "Found source subscription" -MessageType "INFO" -LogFile $LogFile
        Select-AzureRmSubscription -SubscriptionId $AZURE_SOURCE_SUBSCRIPTION_ID | Out-Null
    }
    else {
        Write-LogFile -Message "Error finding source subscription!" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    }

    if ($subscriptions.SubscriptionId -contains $AZURE_DESTINATION_SUBSCRIPTION_ID) {
        Write-LogFile -Message "Found destination subscription" -MessageType "INFO" -LogFile $LogFile
    }
    else {
        Write-LogFile -Message "Error finding destination subscription!" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    }


    #Define Variables
    $sourceStorageAccounts = Get-AzureRmStorageAccount
    $sourceStorageAccountName = ($IMAGE_URI.Split("/")[2]).Split(".")[0]
    $sourceResourceGroupName = ($sourceStorageAccounts | Where-Object {$_.StorageAccountName -eq $sourceStorageAccountName}).ResourceGroupName
    $imageContainer = "system"

    # Source Storage Account Information
    $sourceKey = ((Get-AzureRmStorageAccountKey -ResourceGroupName $sourceResourceGroupName -Name $sourceStorageAccountName) | Where-Object KeyName -eq "key1").Value
    $sourceContext = New-AzureStorageContext –StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceKey

    # Destination Storage Account Information
    Select-AzureRmSubscription -SubscriptionId $AZURE_DESTINATION_SUBSCRIPTION_ID | Out-Null
    $destStorageAccounts = Get-AzureRmStorageAccount
    $destinationResourceGroupName = ($destStorageAccounts | Where-Object {$_.StorageAccountName -eq $DESTINATION_STORAGE_ACCOUNT}).ResourceGroupName
    $destinationKey = ((Get-AzureRmStorageAccountKey -ResourceGroupName $destinationResourceGroupName -Name $DESTINATION_STORAGE_ACCOUNT) | Where-Object KeyName -eq "key1").Value
    $destinationContext = New-AzureStorageContext –StorageAccountName $DESTINATION_STORAGE_ACCOUNT -StorageAccountKey $destinationKey  

    # Ensure the destination container exists
    $destinationContainers = Get-AzureStorageContainer -Context $destinationContext
    if(!($destinationContainers.Name -contains $imagecontainer)) {
        Write-LogFile -Message "Creating destination container" -MessageType "INFO" -LogFile $LogFile
        $result = New-AzureStorageContainer -Name $imagecontainer -Context $destinationContext 
    }

    # Copy the blob
    $blobName = $IMAGE_URI.Replace("$($sourceContext.BlobEndPoint)$($imageContainer)/","")
    Write-LogFile -Message "Starting blob copy" -MessageType "INFO" -LogFile $LogFile
    $blobCopy = Start-AzureStorageBlobCopy -DestContainer $imagecontainer `
                            -DestContext $destinationContext `
                            -SrcBlob $blobName `
                            -Context $sourceContext `
                            -SrcContainer $imagecontainer

    if ($wait) {
        # Wait for copy to finish...
        $copy_complete = $false
        while ($copy_complete -eq $false) {
            $copystate = $blobcopy | Get-AzureStorageBlobCopyState
            if($copystate.status -eq "Pending") {
                Start-Sleep -Seconds 15
            }
            elseif ($copystate.Status -eq "Success") {
                Write-LogFile -Message "Copy Complete!" -MessageType "INFO" -LogFile $LogFile
                $copy_complete = $true
            }
            else {
                Write-LogFile -Message "Unknown copy state: $($copystate.status)" -MessageType "ERROR" -LogFile $LogFile
                EXIT 1
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