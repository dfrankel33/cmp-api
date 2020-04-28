param(
  $RS_HOST = "us-3.rightscale.com", #or us-4.rightscale.com,
  $ACCOUNT_ID = "",
  $GRS_ACCOUNT = "",
  $REFRESH_TOKEN = "",
  $CRED_NAME = "",
  $CRED_ID = "",
  $CRED_DESC = "",
  $ROLE_ARN = ""
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

function Get-AWSSTSCredential ($RS_HOST, $ACCESS_TOKEN, $ACCOUNT_ID, $CRED_ID) {
  try {
    Write-Output "Indexing credentials in Project ID: $ACCOUNT_ID..."
    
    $contentType = "application/json"
    
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials/aws_sts/$CRED_ID"

    $credsResult = Invoke-RestMethod -UseBasicParsing -Uri "https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials/aws_sts/$CRED_ID" -Method Get -Headers $header -ContentType $contentType

    return $credsResult
  }
  catch {
      Write-Output "Error retrieving credentials! $($_ | Out-String)" 
  }
}

function Create-AWSSTSCredential ($RS_HOST, $ACCESS_TOKEN, $ACCOUNT_ID, $CRED_NAME, $CRED_ID, $CRED_DESC, $GRS_ACCOUNT, $ROLE_ARN) {
  try {
    Write-Output "Indexing credentials in Project ID: $ACCOUNT_ID..."
    
    $contentType = "application/json"
    $header = @{"Api-Version"="1.0";"Authorization"="Bearer $ACCESS_TOKEN"}
    $body = [ordered]@{"description"=$CRED_DESC;"external_id"=$GRS_ACCOUNT;"name"=$CRED_NAME;"role_arn"=$ROLE_ARN;"role_session_name"="flexera-policies";"tags"=@([ordered]@{"key"="provider";"value"="aws"};[ordered]@{"key"="ui";"value"="aws_sts"})} | ConvertTo-Json
    $shard = $RS_HOST.split("-")[1]
    Write-Output "URI: https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials/aws_sts/$CRED_ID"

    $putCredResult = Invoke-RestMethod -UseBasicParsing -Uri "https://cloud-$shard/cloud/projects/$ACCOUNT_ID/credentials/aws_sts/$CRED_ID" -Method Put -Headers $header -ContentType $contentType -Body $body

    return $putCredResult
  }
  catch {
      Write-Output "Error creating credential! $($_ | Out-String)" 
  }
}

#Auth
$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token

#Index Creds
$existingCreds = Index-Credentials -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -ACCOUNT_ID $ACCOUNT_ID

if ($existingCreds.items.id -contains $CRED_ID) {
  Write-Output "A Credential with that ID already exists in Project $ACCOUNT_ID"
  $matchingCred = $existingCreds.items | where id -eq $CRED_ID
  Write-Output $matchingCred
} else {
  Write-Output "Creating Credential $CRED_ID..."
  Create-AWSSTSCredential -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -ACCOUNT_ID $ACCOUNT_ID -CRED_NAME $CRED_NAME -CRED_ID $CRED_ID -CRED_DESC $CRED_DESC -GRS_ACCOUNT $GRS_ACCOUNT -ROLE_ARN $ROLE_ARN
  $newCred = Get-AWSSTSCredential -ACCESS_TOKEN $accessToken -RS_HOST $RS_HOST -ACCOUNT_ID $ACCOUNT_ID -CRED_ID $CRED_ID
  Write-Output $newCred
}