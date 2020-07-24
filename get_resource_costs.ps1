param(
  $GRS_ACCOUNT = "28507",
  $REFRESH_TOKEN = "2b54613f86bf9db092b9affa5508f362e2039e95",
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

function Get-BcCosts ($ACCESS_TOKEN, $GRS_ACCOUNT, $BC_IDS, $START_DAY, $END_DAY){
  try {
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = [ordered]@{"billing_center_ids"=$BC_IDS;"dimensions"=@("usage_unit","category","service","instance_type","line_item_type","region","resource_type","usage_type");"start_at"=$START_DAY;"end_at"=$END_DAY;"granularity"="day";"metrics"=@("cost_nonamortized_unblended_adj","usage_amount")} | ConvertTo-Json

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
$parentBCs = $existingBCs | where parent_id -eq $null
$today = get-date
$daysInMonth = $today.day +1
$numberOfDays = @(1..30)

$monthlyCosts = @()
foreach ($day in $numberOfDays) {
  $costs = Get-BcCosts -ACCESS_TOKEN $accessToken -GRS_ACCOUNT $GRS_ACCOUNT -BC_IDS $parentBCs.id -START_DAY "2020-06-$day" -END_DAY "2020-06-$($day+1)"
  foreach ($cost in $costs.rows){
    $object = New-Object psobject
    $object | Add-Member -MemberType NoteProperty -Name UsageStartTime -Value "2020-06-$day"
    $object | Add-Member -MemberType NoteProperty -Name UsageAmount -Value $($cost.metrics.usage_amount -as [decimal])
    $object | Add-Member -MemberType NoteProperty -Name Cost -Value $($cost.metrics.cost_nonamortized_unblended_adj -as [decimal])
    $object | Add-Member -MemberType NoteProperty -Name Category -Value $cost.dimensions.category
    $object | Add-Member -MemberType NoteProperty -Name InstanceType -Value $cost.dimensions.instance_type
    $object | Add-Member -MemberType NoteProperty -Name LineItemType -Value $cost.dimensions.line_item_type
    $object | Add-Member -MemberType NoteProperty -Name Region -Value $cost.dimensions.region
    $object | Add-Member -MemberType NoteProperty -Name ResourceType -Value $cost.dimensions.resource_type
    $object | Add-Member -MemberType NoteProperty -Name Service -Value $cost.dimensions.service
    $object | Add-Member -MemberType NoteProperty -Name UsageType -Value $cost.dimensions.usage_type
    $object | Add-Member -MemberType NoteProperty -Name UsageUnit -Value $cost.dimensions.usage_unit
    $monthlyCosts += $object
  }
}

$monthlyCosts | Export-Csv .\costs-export.csv