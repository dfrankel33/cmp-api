param(
  $RS_HOST = "us-3.rightscale.com",
  $EMAIL_DOMAIN = "example.com",
  $GRS_ACCOUNT = "27684",
  $RS_ACCOUNT = "121503",
  $REFRESH_TOKEN = ""
)

$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token
        
$grsHeader = @{"X-API-Version"="2.0";"Authorization"="Bearer $AccessToken"}

$orgUsers = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ACCOUNT/users" -Method Get -Headers $grsHeader -ContentType $contentType
$users = @()
foreach ($orgUser in $orgUsers){
  if ($orgUser.email -like "*$EMAIL_DOMAIN") {
    $users += $orgUser.href
  } else {
    # Skip user
  }
}

$orgProjects = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ACCOUNT/projects" -Method Get -Headers $grsHeader -ContentType $contentType
$projects = @()
foreach ($orgProject in $orgProjects) {
  $projects += "grs/orgs/$GRS_ACCOUNT/projects/$($orgProject.id)"
}
$projects += "grs/orgs/$GRS_ACCOUNT"

foreach ($project in $projects){
  foreach ($user in $users){
    $payload = [ordered]@{
      "subject_href" = $user
    } | ConvertTo-Json
    # Get Roles in the Project (or applied at Org)
    $userRoles = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/$project/access_reports/roles" -Method Post -Headers $grsHeader -ContentType $contentType -Body $payload
    $roles = $userRoles.items.access_rules.links.role.href
    
    # Revoke explicit roles
    foreach ($role in $roles){
      $payload = [ordered]@{
        "subject" = [ordered]@{
          "href" = $user
        }
        "role" = [ordered]@{
          "href" = $role
        }
      } | ConvertTo-Json
      Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/$project/access_rules/revoke" -Method Put -Headers $grsHeader -ContentType $contentType -Body $payload
    }
  }
}

foreach ($user in $users){
  $payload = @{"view"="extended"}
  $userDetails = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ACCOUNT/users/$($user.split('/')[3])" -Method Get -Headers $grsHeader -ContentType $contentType -Body $payload
  $groups = $userDetails.groups.href
  
  foreach ($group in $groups){
    $groupDetails = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_Host$group" -Method Get -Headers $grsHeader -ContentType $contentType -Body $payload
    $groupUsers = $groupDetails.users
    $userPayload = @()
    foreach ($groupUser in $groupUsers){
      if ($($groupUser.email) -notlike "*$EMAIL_DOMAIN"){
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
    Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ACCOUNT/memberships" -Method Put -Headers $grsHeader -ContentType $contentType -Body $newMembershipPayload
  }
}