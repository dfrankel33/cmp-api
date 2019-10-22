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

#List AWS Instances
$awsInstancesBody = @{
  "billing_center_ids"=$($topLevelBCs.id); 
  "dimensions"=@("vendor","vendor_account","category","instance_type","region","resource_type","service","usage_type","usage_unit","resource_id");
  "granularity"="day"; 
  "start_at"=$start_date; 
  "end_at"=$end_date; 
  "limit"=100000; 
  "metrics"=@("usage_amount"); 
  "filter"= @{
    "type"="and"; 
    "expressions"= @(
      @{"dimension"="category";"type"="equal";"value"="Compute"},
      @{"dimension"="service";"type"="equal";"value"="AmazonEC2"},
      @{"dimension"="vendor";"type"="equal";"value"="AWS"},
      @{"dimension"="resource_type";"type"="equal";"value"="Compute Instance"}
    )
  }
}

$awsInstances = Invoke-RestMethod -Method Post -Uri $baUri -Headers $optimaHeaders -Body ($awsInstancesBody | ConvertTo-Json -Depth 3) -ContentType "application/json"

$azureInstancesBody = @{
  "billing_center_ids"=$($topLevelBCs.id); 
  "dimensions"=@("vendor","vendor_account","category","instance_type","region","resource_type","service","usage_type","usage_unit","resource_id");
  "granularity"="day"; 
  "start_at"=$start_date; 
  "end_at"=$end_date; 
  "limit"=100000; 
  "metrics"=@("usage_amount"); 
  "filter"= @{
    "type"="and";
    "expressions"=@(
      @{"dimension"="category";"type"="equal";"value"="Compute"},
      @{"type"="or"; "expressions"=@(
        @{"dimension"="vendor";"type"="equal";"value"="Azure"},
        @{"dimension"="vendor";"type"="equal";"value"="AzureCSP"}
      )},
      @{"dimension"="service";"type"="equal";"value"="Microsoft.Compute"},
      @{"type"="or";"expressions"=@(
        @{"dimension"="usage_unit";"type"="equal";"value"="Hour"},
        @{"dimension"="usage_unit";"type"="equal";"value"="Hours"}
      )}
    )
  }
}

$azureResponse = Invoke-RestMethod -Method Post -Uri $baUri -Headers $optimaHeaders -Body ($azureInstancesBody | ConvertTo-Json -Depth 5) -ContentType "application/json"

$googleInstancesBody = @{
  "billing_center_ids"=$($topLevelBCs.id); 
  "dimensions"=@("vendor","vendor_account","category","instance_type","region","resource_type","service","usage_type","usage_unit","resource_id");
  "granularity"="day"; 
  "start_at"=$start_date; 
  "end_at"=$end_date; 
  "limit"=100000; 
  "metrics"=@("usage_amount"); 
  "filter"= @{
    "type"="and";
    "expressions"=@(
      @{"dimension"="category";"type"="equal";"value"="Compute"},
      @{"dimension"="vendor";"type"="equal";"value"="GCP"},
      @{"dimension"="service";"type"="equal";"value"="Compute Engine"},
      @{"dimension"="usage_unit";"type"="equal";"value"="hour"}
    )
  }
}

$googleResponse = Invoke-RestMethod -Method Post -Uri $baUri -Headers $optimaHeaders -Body ($googleInstancesBody | ConvertTo-Json -Depth 3) -ContentType "application/json"

#Filter out non-instance resources from GCP
$googleInstances = @()
foreach($resource in $($googleResponse.rows)){ 
  if ($resource.dimensions.resource_type -like "*Instance*") { 
    $googleInstances += $resource 
  }
}

#Filter out licenses from Azure
$azureInstances = @()
foreach($resource in $($azureResponse.rows)){
  if ($resource.dimensions.resource_type -notlike "*Licenses*"){
    $azureInstances += $resource
  }
}

$all_instances = $googleInstances + $azureInstances + $awsInstances
$output = @()
foreach ($instance in $($all_instances.rows)) {
  $object = New-Object -TypeName PSObject
  $object | Add-Member -MemberType NoteProperty -Name "Hours" -Value $instance.metrics.usage_amount
  $object | Add-Member -MemberType NoteProperty -Name "ResourceID" -Value $instance.dimensions.resource_id
  $object | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $instance.dimensions.resource_type
  $object | Add-Member -MemberType NoteProperty -Name "CloudVendor" -Value $instance.dimensions.vendor
  $object | Add-Member -MemberType NoteProperty -Name "CloudAccountID" -Value $instance.dimensions.vendor_account
  $object | Add-Member -MemberType NoteProperty -Name "Region" -Value $instance.dimensions.region
  $object | Add-Member -MemberType NoteProperty -Name "InstanceType" -Value $instance.dimensions.instance_type
  $output += $object
} 

$formatted_output = $output | Group-Object -Property ResourceID

$final_output = @()
foreach ($data in $formatted_output) {
  $object = New-Object -TypeName PSObject
  $totalhours = 0
  $data.Group.Hours | ForEach-Object { $totalhours += $_}
  $object | Add-Member -MemberType NoteProperty -Name "Hours" -Value $totalhours
  $object | Add-Member -MemberType NoteProperty -Name "ResourceID" -Value $data.Name
  $object | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $data.Group[0].ResourceType
  $object | Add-Member -MemberType NoteProperty -Name "CloudVendor" -Value $data.Group[0].CloudVendor
  $object | Add-Member -MemberType NoteProperty -Name "CloudAccountID" -Value $data.Group[0].CloudAccountID
  $object | Add-Member -MemberType NoteProperty -Name "Region" -Value $data.Group[0].Region
  $object | Add-Member -MemberType NoteProperty -Name "InstanceType" -Value $data.Group[0].InstanceType
  $final_output += $object
}

return $final_output