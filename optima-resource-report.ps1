[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [string]$refresh_token,
   [Parameter(Mandatory=$True)]
   [string]$rs_host,
   [Parameter(Mandatory=$True)]
   [string]$org_id,
   [Parameter(Mandatory=$True)]
   [string]$start_date,
   [Parameter(Mandatory=$True)]
   [string]$end_date
)

#Generate Access Token
$oauthHeaders = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$refresh_token}
$oauthUri = "https://"+$rs_host+"/api/oauth2"
$oauthResult = Invoke-RestMethod -Method Post -Uri $oauthUri -Headers $oauthHeaders -Body ($oauthBody | ConvertTo-Json) -ContentType "application/json"
$accessToken = $oauthResult.access_token

$bcUri = "https://optima.rightscale.com/analytics/orgs/"+$org_id+"/billing_centers"
$baUri = "https://optima.rightscale.com/bill-analysis/orgs/"+$org_id+"/costs/select"
$optimaHeaders = @{"Api-Version"="1.0"; "Authorization"="Bearer $accessToken"}

#List Billing Centers
$bcResult = Invoke-RestMethod -Method Get -Uri $bcUri -Headers $optimaHeaders 
#Filter out child BCs 
$topLevelBCs = $bcResult | Where-Object "parent_id" -eq $null

$all_resources = @()
foreach ($bc in $topLevelBCs){
  $payload = @{
    "billing_center_ids"=@($bc.id); 
    "dimensions"=@("vendor","vendor_account","category","region","resource_type","service","usage_unit","resource_id");
    "granularity"="day"; 
    "start_at"=$start_date; 
    "end_at"=$end_date; 
    "limit"=100000; 
    "metrics"=@("cost_nonamortized_unblended_adj","usage_amount"); 
  }

  $resources = Invoke-RestMethod -Method Post -Uri $baUri -Headers $optimaHeaders -Body ($payload | ConvertTo-Json) -ContentType "application/json"
  $all_resources += $resources
}

$output = @()
foreach ($resource in $($all_resources.rows)) {
  $object = New-Object -TypeName PSObject
  $object | Add-Member -MemberType NoteProperty -Name "Cost" -Value $resource.metrics.cost_nonamortized_unblended_adj
  $object | Add-Member -MemberType NoteProperty -Name "UsageAmount" -Value $resource.metrics.usage_amount
  $object | Add-Member -MemberType NoteProperty -Name "UsageUnit" -Value $resource.dimensions.usage_unit
  $object | Add-Member -MemberType NoteProperty -Name "ResourceID" -Value $resource.dimensions.resource_id
  $object | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $resource.dimensions.resource_type
  $object | Add-Member -MemberType NoteProperty -Name "CloudVendor" -Value $resource.dimensions.vendor
  $object | Add-Member -MemberType NoteProperty -Name "CloudAccountID" -Value $resource.dimensions.vendor_account
  $object | Add-Member -MemberType NoteProperty -Name "Category" -Value $resource.dimensions.category
  $object | Add-Member -MemberType NoteProperty -Name "Service" -Value $resource.dimensions.service
  $object | Add-Member -MemberType NoteProperty -Name "Region" -Value $resource.dimensions.region
  $object | Add-Member -MemberType NoteProperty -Name "Timestamp" -Value $resource.timestamp
  $output += $object
} 


return $output