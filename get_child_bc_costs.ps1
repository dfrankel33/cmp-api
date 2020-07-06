param(
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $RS_HOST = "us-3.rightscale.com"
)

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

function Get-BcCosts ($ACCESS_TOKEN, $GRS_ACCOUNT, $BC_IDS, $START_MONTH, $END_MONTH){
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = [ordered]@{"billing_center_ids"=$BC_IDS;"dimensions"=@("billing_center_id");"start_at"=$START_MONTH;"end_at"=$END_MONTH;"granularity"="month";"metrics"=@("cost_amortized_blended_adj")} | ConvertTo-Json

    $bcResult = Invoke-RestMethod -UseBasicParsing -Uri "https://optima.rightscale.com/bill-analysis/orgs/$GRS_ACCOUNT/costs/aggregated" -Method Post -Headers $header -ContentType $contentType -Body $body

    return $bcResult
  }
  catch {
      Write-Output "Error retrieving BC Costs! $($_ | Out-String)" 
  }
}

#Generate Access Token
$oauthHeaders = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$refresh_token}
$oauthUri = "https://"+$rs_host+"/api/oauth2"
$oauthResult = Invoke-RestMethod -Method Post -Uri $oauthUri -Headers $oauthHeaders -Body ($oauthBody | ConvertTo-Json) -ContentType "application/json"
$accessToken = $oauthResult.access_token

#Index BCs
$existingBCs = Index-BCs -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT
$currentMonth = (get-date -Format yyyy-MM).toString()
$nextMonth = (get-date (get-date).AddMonths(1) -Format yyyy-MM).ToString()

$allBcCosts = @()
foreach ($parentId in ($existingBCs.parent_id | select -Unique)) {
  $childBcs = $existingBCs | where parent_id -eq $parentId
  $costs = Get-BcCosts -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_IDS $childBcs.id -START_MONTH $currentMonth -END_MONTH $nextMonth
  $allBcCosts += $costs
}
$costs = Get-BcCosts -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_IDS ($existingBCs | where parent_id -eq $null).id -START_MONTH $currentMonth -END_MONTH $nextMonth
$allBcCosts += $costs

$output = @()
foreach ($row in $allBcCosts.rows){
  $object = New-Object psobject
  $object | Add-Member -MemberType NoteProperty -Name bc_id -Value $row.dimensions.billing_center_id
  $object | Add-Member -MemberType NoteProperty -Name cost -Value $row.metrics.cost_amortized_blended_adj
  $object | Add-member -MemberType NoteProperty -Name bc_name -Value ($existingBCs | where id -eq $row.dimensions.billing_center_id).name
  $object | Add-member -MemberType NoteProperty -Name parent_name -Value ($existingBCs | where id -eq ($existingBCs | where id -eq $row.dimensions.billing_center_id).parent_id).name
  $output += $object
}

return $output