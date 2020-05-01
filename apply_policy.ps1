param(
  $RS_HOST = "us-3.rightscale.com", #or us-4.rightscale.com,
  $ACCOUNT_ID = "",
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $POLICY_NAME = "",
  $FREQUENCY = "",
  $OPTIONS 
)


function Index-Credentials ($RS_HOST, $ACCESS_TOKEN, $ACCOUNT_ID) {
  try {
    Write-Output "Indexing credentials in Project ID: $ACCOUNT_ID..."
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials"

    $credsResult = Invoke-RestMethod -UseBasicParsing -Uri "https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials" -Method Get -Headers $header -ContentType $contentType

    return $credsResult
  }
  catch {
      Write-Output "Error retrieving credentials! $($_ | Out-String)" 
  }
}

function Create-Policy ($RS_HOST, $ACCESS_TOKEN, $ACCOUNT_ID, $CRED_ID, $GRS_ACCOUNT, $POLICY_NAME, $FREQUENCY, $OPTIONS, $SEVERITY, $TEMPLATE_HREF) {
  try {
    Write-Output "Creating Policy: $POLICY_NAME"
    Write-Output "with Credential: $CRED_ID" 
    Write-Output "in Project ID: $ACCOUNT_ID"
    
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = [ordered]@{"description"="Applied via API";"name"="$CRED_ID`: $POLICY_NAME";"frequency"=$FREQUENCY;"credentials"=[ordered]@{"auth_aws"=$CRED_ID};"options"=$($OPTIONS);"project_ids"=@($ACCOUNT_ID -as [int]);"severity"=$SEVERITY;"skip_approvals"=false;"template_href"=$TEMPLATE_HREF} | ConvertTo-Json -Depth 5
    Write-Output $body
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard/api/governance/org/$GRS_ACCOUNT/policy_aggregates"

    $createPolicyResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/policy_aggregates" -Method Post -Headers $header -ContentType $contentType -Body $body

    return $createPolicyResult
  }
  catch {
      Write-Output "Error creating policy! $($_ | Out-String)" 
  }
}

function Index-PublishedTemplates ($RS_HOST, $ACCESS_TOKEN, $GRS_ACCOUNT) {
  try {
    Write-Output "Getting Published Templates in Org ID: $GRS_ACCOUNT"
    
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://governance-$shard/api/governance/org/$GRS_ACCOUNT/published_templates"

    $publishedTemplatesResult = Invoke-RestMethod -UseBasicParsing -Uri "https://governance-$shard/api/governance/orgs/$GRS_ACCOUNT/published_templates" -Method Get -Headers $header -ContentType $contentType

    return $publishedTemplatesResult
  }
  catch {
    Write-Output "Error getting policy details! $($_ | Out-String)" 
  }
}

#Auth
$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token

#Index Published Templates
$publishedTemplates = Index-PublishedTemplates -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -GRS_ACCOUNT $GRS_ACCOUNT
$targetTemplate = $publishedTemplates.items | where name -eq $POLICY_NAME
$severity = $targetTemplate.severity
$template_href = $targetTemplate.href 

#Index Creds
$existingCreds = (Index-Credentials -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -ACCOUNT_ID $ACCOUNT_ID).items

foreach ($cred in $existingCreds) {
  if ($cred.id -eq $existingCreds[1].id){
    Write-Output "First Policy has run."
    $continue = Read-Host "Continue? (y/n)"
  } elseif ($cred.id -eq $existingCreds[0].id) {$continue = "y"}
  if ($continue -ne "y") {
    Write-Output "Skipping.."
  } else {
    Create-Policy -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -ACCOUNT_ID $ACCOUNT_ID -GRS_ACCOUNT $GRS_ACCOUNT -SEVERITY $severity -FREQUENCY $FREQUENCY -CRED_ID $cred.id -POLICY_NAME $POLICY_NAME -TEMPLATE_HREF $template_href -OPTIONS $OPTIONS
  }
}