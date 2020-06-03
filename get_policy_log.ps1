param(
  $RS_HOST = "us-3.rightscale.com", #or us-4.rightscale.com,
  $ACCOUNT_ID = "",
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $POLICY_NAME = ""
)

function Index-PolicyAggregates ($RS_HOST, $ACCESS_TOKEN, $GRS_ACCOUNT) {
  try {
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/policy_aggregates"

    $indexPoliciesResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/policy_aggregates" -Method Get -Headers $header -ContentType $contentType

    return $indexPoliciesResult
  }
  catch {
      Write-Output "Error creating policy! $($_ | Out-String)" 
  }
}

function Get-PolicyAggregate ($RS_HOST, $ACCESS_TOKEN, $HREF){
  try {
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard$HREF"

    $policyAggResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard$HREF" -Method Get -Headers $header -ContentType $contentType

    return $policyAggResult
  }
  catch {
      Write-Output "Error creating policy! $($_ | Out-String)" 
  }
}

function Get-PolicyLog ($ACCESS_TOKEN, $URL){
  try {
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    Write-Output "URI: $URL/log"

    $policyLogResult = Invoke-RestMethod -UseBasicParsing -Uri "$URL/log" -Method Get -Headers $header -ContentType $contentType

    return $policyLogResult
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

$policies = Index-PolicyAggregates -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -GRS_ACCOUNT $GRS_ACCOUNT

$target_policy = $policies.items | where name -eq $POLICY_NAME

$policy_agg = Get-PolicyAggregate -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -HREF $target_policy.href

$policy_log = Get-PolicyLog -ACCESS_TOKEN $accessToken -URL $policy_agg.items.url
return $policy_log

