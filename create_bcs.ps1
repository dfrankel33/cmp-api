param(
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $RS_HOST = "us-3.rightscale.com",
  $CSV_PATH = ""
)

#Mandatory CSV headers: project_id,bc1,bc2,bc3
#project_id = cloud vendor account ID
#bc1 = top-level Billing Center name
#bc2 = 2nd level BC name
#bc3 = 3rd level BC name

function Index-BCs ($ACCESS_TOKEN, $GRS_ACCOUNT) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}

    $bcResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com/analytics/orgs/$GRS_ACCOUNT/billing_centers" -Method Get -Headers $header -ContentType $contentType

    return $bcResult
  }
  catch {
      Write-Output "Error retrieving BCs! $($_ | Out-String)" 
  }
}

function Create-BC ($ACCESS_TOKEN, $GRS_ACCOUNT, $BC_NAME, $PARENT_HREF) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = [ordered]@{"description"="";"name"=$BC_NAME;"parent_href"=$PARENT_HREF} | ConvertTo-Json

    $createBCResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com/analytics/orgs/$GRS_ACCOUNT/billing_centers" -Method Post -Headers $header -ContentType $contentType -Body $body

    return $createBCResult
  }
  catch {
      Write-Output "Error creating BC! $($_ | Out-String)" 
  }
}

function Update-AllocationTable ($ACCESS_TOKEN, $GRS_ACCOUNT, $PAYLOAD, $SEQUENCE_NUMBER) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="0.1";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = $PAYLOAD | ConvertTo-Json -Depth 4

    $createBCResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com/analytics/orgs/$GRS_ACCOUNT/allocation_table?sequence_number=$SEQUENCE_NUMBER" -Method Put -Headers $header -ContentType $contentType -Body $body

    return $createBCResult
  }
  catch {
      Write-Output "Error updating allocation table! $($_ | Out-String)" 
  }
}

function Get-AllocationTable ($ACCESS_TOKEN, $GRS_ACCOUNT) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="0.1";"Authorization"="Bearer $ACCESS_TOKEN"}

    $createBCResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com/analytics/orgs/$GRS_ACCOUNT/allocation_table" -Method Get -Headers $header -ContentType $contentType

    return $createBCResult
  }
  catch {
      Write-Output "Error retrieving allocation table! $($_ | Out-String)" 
  }
}

function Get-ChildAllocationTable ($ACCESS_TOKEN, $PARENT_HREF) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="0.1";"Authorization"="Bearer $ACCESS_TOKEN"}

    $createBCResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com$PARENT_HREF/allocation_table" -Method Get -Headers $header -ContentType $contentType

    return $createBCResult
  }
  catch {
      Write-Output "Error retrieving allocation table! $($_ | Out-String)" 
  }
}

function Update-ChildAllocationTable ($ACCESS_TOKEN, $PARENT_HREF, $PAYLOAD, $SEQUENCE_NUMBER) {
  try {
    
    if ($SEQUENCE_NUMBER -eq $null){
      $url = "https://optima.rightscale.com$PARENT_HREF/allocation_table"
    } else {
      $url = "https://optima.rightscale.com$PARENT_HREF/allocation_table?sequence_number=$SEQUENCE_NUMBER"
    }
    $contentType = "application/json"
    
    $header = @{"Api-Version"="0.1";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = $PAYLOAD | ConvertTo-Json -Depth 4

    $createBCResult = Invoke-RestMethod -UseBasicParsing -Uri $url -Method Put -Headers $header -ContentType $contentType -Body $body

    return $createBCResult
  }
  catch {
      Write-Output "Error updating allocation table! $($_ | Out-String)" 
  }
}

function Get-BC ($ACCESS_TOKEN, $BC_HREF) {
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}

    $bcResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com$BC_HREF" -Method Get -Headers $header -ContentType $contentType

    return $bcResult
  }
  catch {
      Write-Output "Error getting BC! $($_ | Out-String)" 
  }
}


#Generate Access Token
$oauthHeaders = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$refresh_token}
$oauthUri = "https://"+$rs_host+"/api/oauth2"
$oauthResult = Invoke-RestMethod -Method Post -Uri $oauthUri -Headers $oauthHeaders -Body ($oauthBody | ConvertTo-Json) -ContentType "application/json"
$accessToken = $oauthResult.access_token

$rules = import-csv $CSV_PATH

#Index BCs
$existingBCs = Index-BCs -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT

#Create non-existant BCs
$topLevelBcNames = $rules.bc1 | select -unique
foreach ($topLevelBcName in $topLevelBcNames) {
  if (($existingBCS | where parent_id -eq $null | where name -ne unallocated).name -notcontains $topLevelBcName){
    Create-BC -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_NAME $topLevelBcName
  }
}

#Index BCs (again)
$existingBCs = Index-BCs -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT
$topLevelBcs = $existingBCs | where parent_id -eq $null | where name -ne unallocated

#Create Allocation Table
$allocationTable = Get-AllocationTable -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT
$currentSequenceNumber = $allocationTable.sequence_number

$putBcRules = @()
foreach ($topLevelBcName in $topLevelBcNames) {
  $accountIds = ($rules | where bc1 -eq $topLevelBcName).project_id
  $bc_href = ($topLevelBcs | where name -eq $topLevelBcName).href
  if ($accountIds.count -lt 2){$accountIds = @($accountIds)} 
  $allocationRule = [ordered]@{"billing_center"=[ordered]@{"href"=$bc_href};"cloud_vendor_account_ids"=$accountIds}
  $putBcRules += $allocationRule
}
$topLevelAllocationTable = [ordered]@{"allocation_rules"=$putBcRules;"sequence_number"=$currentSequenceNumber}

#Put top-level Allocation Table
Update-AllocationTable -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -PAYLOAD $topLevelAllocationTable -SEQUENCE_NUMBER $currentSequenceNumber

#Loop through Top-Level BCs
foreach ($topLevelBc in $topLevelBcs){
  Write-Output "Looping on $($topLevelBc.name)"
  $childBcNames = ($rules | where bc1 -eq $topLevelBC.name | where bc2 -ne "").bc2 | select -unique
  #Index Child BCs
  $topLevelBC = Get-BC -ACCESS_TOKEN $accessToken -BC_HREF $topLevelBC.href 
  if ($topLevelBC.children -eq $null){
    # Create all child BCs
    foreach ($childBcName in $childBcNames){
      Create-BC -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_NAME $childBcName -PARENT_HREF $topLevelBC.href
    }
  } else {
    #Create non-existant Child BCs
    foreach ($childBcName in $childBcNames){
      if (($topLevelBC.children | where name -ne unallocated).name -notcontains $childBcName){
        Create-BC -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_NAME $childBcName -PARENT_HREF $topLevelBC.href
      }
    }
  }
  #Index Child BCs (again)
  $topLevelBc = Get-BC -ACCESS_TOKEN $accessToken -BC_HREF $topLevelBC.href 

  #Get current Allocation Table
  $childAllocationTable = Get-ChildAllocationTable -ACCESS_TOKEN $accessToken -PARENT_HREF $topLevelBc.href
  $currentSequenceNumber = $childAllocationTable.sequence_number
  $putBcRules = @()
  foreach ($childBcName in $childBcNames) {
    $accountIds = ($rules | where bc2 -eq $childBcName).project_id
    $bcId = ($topLevelBc.children | where name -eq $childBcName).id 
    $bcHref = "/analytics/orgs/$GRS_ACCOUNT/billing_centers/$bcId"
    if ($accountIds.count -lt 2){$accountIds = @($accountIds)} 
    $allocationRule = [ordered]@{"billing_center"=[ordered]@{"href"=$bcHref};"cloud_vendor_account_ids"=$accountIds}
    $putBcRules += $allocationRule
  }
  if ($currentSequenceNumber -eq $null){
    $allocationTable = [ordered]@{"allocation_rules"=$putBcRules}
  } else {
    $allocationTable = [ordered]@{"allocation_rules"=$putBcRules;"sequence_number"=$currentSequenceNumber}
  }
  #Put child BC Allocation Table
  Update-ChildAllocationTable -ACCESS_TOKEN $accessToken -PARENT_HREF $topLevelBc.href -PAYLOAD $allocationTable -SEQUENCE_NUMBER $currentSequenceNumber
}

#Index BCs (again)
$existingBCs = Index-BCs -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT
$childBCs = $existingBCs | where parent_id -In $topLevelBCs.id | where name -ne unallocated
#Loop through Child BCs
foreach ($parentBc in $childBCs){
  Write-Output "Looping on $($parentBc.name)"
  $childBcNames = ($rules | where bc2 -eq $parentBc.name | where bc3 -ne "").bc3 | select -unique
  #Index Child BCs
  $parentBc = Get-BC -ACCESS_TOKEN $accessToken -BC_HREF $parentBc.href 
  if ($parentBc.children -eq $null){
    # Create all child BCs
    foreach ($childBcName in $childBcNames){
      Create-BC -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_NAME $childBcName -PARENT_HREF $parentBc.href
    }
  } else {
    #Create non-existant Child BCs
    foreach ($childBcName in $childBcNames){
      if (($parentBc.children | where name -ne unallocated).name -notcontains $childBcName){
        Create-BC -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_NAME $childBcName -PARENT_HREF $parentBc.href
      }
    }
  }
  #Index Child BCs (again)
  $parentBc = Get-BC -ACCESS_TOKEN $accessToken -BC_HREF $parentBc.href 

  #Get current Allocation Table
  $childAllocationTable = Get-ChildAllocationTable -ACCESS_TOKEN $accessToken -PARENT_HREF $parentBc.href
  $currentSequenceNumber = $childAllocationTable.sequence_number
  $putBcRules = @()
  foreach ($childBcName in $childBcNames) {
    $accountIds = ($rules | where bc3 -eq $childBcName).project_id
    $bcId = ($parentBc.children | where name -eq $childBcName).id 
    $bcHref = "/analytics/orgs/$GRS_ACCOUNT/billing_centers/$bcId"
    if ($accountIds.count -lt 2){$accountIds = @($accountIds)} 
    $allocationRule = [ordered]@{"billing_center"=[ordered]@{"href"=$bcHref};"cloud_vendor_account_ids"=$accountIds}
    $putBcRules += $allocationRule
  }
  if ($currentSequenceNumber -eq $null){
    $allocationTable = [ordered]@{"allocation_rules"=$putBcRules}
  } else {
    $allocationTable = [ordered]@{"allocation_rules"=$putBcRules;"sequence_number"=$currentSequenceNumber}
  }
  #Put child BC Allocation Table
  Update-ChildAllocationTable -ACCESS_TOKEN $accessToken -PARENT_HREF $parentBc.href -PAYLOAD $allocationTable -SEQUENCE_NUMBER $currentSequenceNumber
}

