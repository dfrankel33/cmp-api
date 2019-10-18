param(
  $RS_HOST = "us-3.rightscale.com",
  $GRS_ORG = "",
  $USER_IDS = @(""), 
  $REFRESH_TOKEN = ""
)

function Remove-OrgUser ($RS_HOST, $ACCESS_TOKEN, $GRS_ORG, $USER_ID) {
    try {
        Write-Output "Removing User (ID: $USER_ID) from Org $GRS_ORG..."
        
        $contentType = "application/json"
        
        $grsHeader = @{
            "X-API-Version"="2.0";
            "Authorization"="Bearer $ACCESS_TOKEN"
        }

        $membershipResult = Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/users/$USER_ID" -Method Delete -Headers $grsHeader
        
        if($membershipResult.StatusCode -eq "204") {
            Write-Output "Successfully removed user!"
        }
        else {
            Write-Output "Error removing user!"
        }
    }
    catch {
        Write-Output "Error removing user! $($_ | Out-String)" 
    }
}

$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token

# Get Role Href
$grsHeader = @{
    "X-API-Version"="2.0";
    "Authorization"="Bearer $accessToken"
}

foreach ($USER_ID in $USER_IDS){
  $payload = @{"view"="extended"}
  $userDetails = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/users/$USER_ID" -Method Get -Headers $grsHeader -ContentType $contentType -Body $payload
  $groups = $userDetails.groups.href
  
  foreach ($group in $groups){
    $groupDetails = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_Host$group" -Method Get -Headers $grsHeader -ContentType $contentType -Body $payload
    $groupUsers = $groupDetails.users
    $userPayload = @()
    foreach ($groupUser in $groupUsers){
      if ($($groupUser.id) -ne $USER_ID){
        $object = New-Object -TypeName PSObject
        $object | Add-Member -MemberType NoteProperty -Name id -Value $groupUser.id 
        $object | Add-Member -MemberType NoteProperty -Name href -Value $groupUser.href
        $object | Add-Member -MemberType NoteProperty -Name kind -Value "user"
        $userPayload += $object
      }
    }

    $newMembershipPayload = [ordered]@{
      "group" = [ordered]@{
          "id" = $group.split('/')[5]
          "href" = $group
          "kind" = "group"
      }
      "users" = @(
          $userPayload
      )
    } | ConvertTo-Json
    Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/memberships" -Method Put -Headers $grsHeader -ContentType $contentType -Body $newMembershipPayload
  }
  
  Remove-OrgUser -RS_HOST $RS_HOST -ACCESS_TOKEN $accessToken -GRS_ORG $GRS_ORG -USER_ID $USER_ID
}
