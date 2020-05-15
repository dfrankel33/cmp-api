param(
  $RS_HOST = "us-3.rightscale.com", #or us-4.rightscale.com,
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $POLICY_NAME = ""
)


function Index-PolicyAggregates ($RS_HOST, $ACCESS_TOKEN, $GRS_ACCOUNT) {
  try {
    Write-Output "Indexing credentials in Project ID: $GRS_ACCOUNT..."
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/policy_aggregates"

    $polAggResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/policy_aggregates" -Method Get -Headers $header -ContentType $contentType

    return $polAggResult
  }
  catch {
      Write-Output "Error retrieving credentials! $($_ | Out-String)" 
  }
}

function Destroy-Policy ($RS_HOST, $ACCESS_TOKEN, $POLICY_HREF) {
  try {
    Write-Output "Destroying Policy: $POLICY_HREF"
    
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard/$POLICY_HREF"

    $destroyPolicyResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard$POLICY_HREF" -Method Delete -Headers $header -ContentType $contentType

    return $destroyPolicyResult
  }
  catch {
      Write-Output "Error creating policy! $($_ | Out-String)" 
  }
}



#Auth
$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token

#Index Published Templates
$policies = Index-PolicyAggregates -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -GRS_ACCOUNT $GRS_ACCOUNT
$targetPolicies = @()
foreach ($policy in $policies.items){
  if ($policy.published_template.name -eq $POLICY_NAME) {
    $targetPolicies += $policy
  }
}
Write-Output "Found $($targetPolicies.count) applied policies for: $POLICY_NAME"

foreach ($policy in $targetPolicies){
  Write-Output "Attempting to destroy $($policy.name)..."
  Destroy-Policy -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -POLICY_HREF $policy.href
}