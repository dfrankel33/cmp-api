function Copy-ASMImage {
<#
.SYNOPSIS
    Copy a custom image in ASM between Storage Accounts and across Subscriptions
.PARAMETER AZURE_DESTINATION_SUBSCRIPTION_ID
    Subscription GUID for Destination Subscription
.PARAMETER AZURE_SOURCE_SUBSCRIPTION_ID
    Subscription GUID for Source Subscription
.PARAMETER DESTINATION_STORAGE_ACCOUNT
    Name of the Destination Storage Account
.PARAMETER IMAGE_NAME
    Name of the source image 
.PARAMETER AZURE_USERNAME
    Username to authenticate with Azure
.PARAMETER AZURE_PASSWORD
    Password to authenticate with Azure.  This value MUST be a securestring.  For example, you could assign this parameter value to a variable prior to executing this function, like this:  $pass = ConvertTo-SecureString -String "P@ssW0rd1" -AsPlainText -Force
.PARAMETER LogFile
    Absolute or relative path to log file
.EXAMPLE
    C:\PS> $secure_string = ConvertTo-SecureString -String "P@ssW0rd1" -AsPlainText -Force
    C:\PS> Copy-ASMImage -AZURE_DESTINATION_SUBSCRIPTION_ID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -AZURE_SOURCE_SUBSCRIPTION_ID yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy -DESTINATION_STORAGE_ACCOUNT storage2 -IMAGE_NAME rl10_windows2012R2.vhd -AZURE_USERNAME john.doe@example.com -AZURE_PASSWORD $secure_string -LogFile C:\Temp\Log.txt
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
        $IMAGE_NAME,

        [Parameter(Mandatory=$true)]
        [string]
        $AZURE_USERNAME,

        [Parameter(Mandatory=$true)]
        [securestring]
        $AZURE_PASSWORD,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile

    )

    Write-LogFile -Message "Starting copy-asmimage" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Source Subscription: $AZURE_SOURCE_SUBSCRIPTION_ID" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Destination Subscription: $AZURE_DESTINATION_SUBSCRIPTION_ID" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Source Image: $IMAGE_NAME" -MessageType "INFO" -LogFile $LogFile
    Write-LogFile -Message "Destination Storage Account: $DESTINATION_STORAGE_ACCOUNT" -MessageType "INFO" -LogFile $LogFile

    $azureAccount = Get-AzureAccount -Name $AZURE_USERNAME -ErrorAction SilentlyContinue
    if (!($azureAccount)) {
        $azureCredential = New-Object System.Management.Automation.PSCredential ($AZURE_USERNAME, $AZURE_PASSWORD)
        Add-AzureAccount -Credential $azureCredential
    }
    else {
        Write-LogFile -Message "Azure Account already added" -MessageType "INFO" -LogFile $LogFile
    }


    #Validate subscriptions
    $subscriptions = Get-AzureSubscription
    if ($subscriptions.SubscriptionId -contains $AZURE_SOURCE_SUBSCRIPTION_ID) {
        Write-LogFile -Message "Found source subscription" -MessageType "INFO" -LogFile $LogFile
        Select-AzureSubscription -SubscriptionId $AZURE_SOURCE_SUBSCRIPTION_ID
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


    $sourceImage = Get-AzureVMImage -ImageName $IMAGE_NAME -ErrorAction SilentlyContinue
    if(!($sourceImage)) {
        Write-LogFile -Message "Error finding source image!" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    }
    $blobname = $sourceImage.MediaLink.AbsoluteUri.Split("/")[-1]
    $sourceStorageAccountName = $sourceImage.MediaLink.host.Split(".")[0]
    $imagecontainer = $sourceImage.MediaLink.LocalPath.Split("/")[1]

    # Source Storage Account Information
    $sourceKey = (Get-AzureStorageKey -StorageAccountName $sourceStorageAccountName).Primary
    $sourceContext = New-AzureStorageContext –StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceKey  

    # Destination Storage Account Information
    Select-AzureSubscription -SubscriptionId $AZURE_DESTINATION_SUBSCRIPTION_ID
    $destinationKey = (Get-AzureStorageKey -StorageAccountName $DESTINATION_STORAGE_ACCOUNT).Primary
    $destinationContext = New-AzureStorageContext –StorageAccountName $DESTINATION_STORAGE_ACCOUNT -StorageAccountKey $destinationKey  

    # Ensure the destination container exists
    $destinationContainers = Get-AzureStorageContainer -Context $destinationContext
    if(!($destinationContainers.Name -contains $imagecontainer)) {
        Write-LogFile -Message "Creating destination container" -MessageType "INFO" -LogFile $LogFile
        $result = New-AzureStorageContainer -Name $imagecontainer -Context $destinationContext 
    }

    # Copy the blob
    Write-LogFile -Message "Starting blob copy" -MessageType "INFO" -LogFile $LogFile
    $blobCopy = Start-AzureStorageBlobCopy -DestContainer $imagecontainer `
                            -DestContext $destinationContext `
                            -SrcBlob $blobName `
                            -Context $sourceContext `
                            -SrcContainer $imagecontainer

    # Wait for copy to finish...
    Write-LogFile -Message "Waiting for copy job to complete" -MessageType "INFO" -LogFile $LogFile
    $copy_complete = $false
    while ($copy_complete -eq $false) {
        $copystate = $blobcopy | Get-AzureStorageBlobCopyState
        if($copystate.status -eq "Pending") {
            Write-LogFile -Message "Copy still in progress..." -MessageType "INFO" -LogFile $LogFile
            Start-Sleep -Seconds 60 
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

    # Register the image in Azure so it will show up in RightScale
    Write-LogFile -Message "Registering ASM Image..." -MessageType "INFO" -LogFile $LogFile
    try {
        Add-AzureVMImage -ImageName $IMAGE_NAME `
            -MediaLocation ("https://{0}.blob.core.windows.net/{1}/{2}" -f $DESTINATION_STORAGE_ACCOUNT, $imagecontainer, $blobName) `
            -OS Windows `
            -Label $IMAGE_NAME `
            -ErrorAction Stop
    } catch {
        Write-LogFile -Message "Error occured while registering image!" -MessageType "ERROR" -LogFile $LogFile
        EXIT 1
    } 
    Write-LogFile -Message "copy-asmimage job completed" -MessageType "INFO" -LogFile $LogFile
}

function Write-LogFile {
    [CmdletBinding()]
    Param([string]$Message, [string]$MessageType, [string]$LogFile)

    $source = $((Get-Variable -Scope 1 MyInvocation -ValueOnly).MyCommand.Name)

    $LogMessage = "$(Get-Date -Format s) - $source - $($MessageType.ToUpper()) - $Message"
    
    Write-Verbose $LogMessage

    Add-Content -Path $LogFile -Value $LogMessage
}