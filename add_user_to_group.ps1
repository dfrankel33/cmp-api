param(
  $RS_HOST = "us-3.rightscale.com",
  $GRS_ACCOUNT = "78",
  $GROUP_ID = "1199",
  $RS_ACCOUNT = "30601",
  $USER_IDS = @("120400"),
  $REFRESH_TOKEN = "900b906efdfa30b73d46a5c972a67fc0726d27fd" #from Frankel-Master
)


function Get-RSGroupMembership ($RSHost, $AccessToken, $GRSAccount, $GroupID) {
    try {
        Write-Output "Listing '$GroupID' membership..."
        
        $contentType = "application/json"
        
        $grsHeader = @{"X-API-Version"="2.0";"Authorization"="Bearer $AccessToken"}
        $body = @{"view"="extended"}
        Write-Output "URI: https://$RSHost/grs/orgs/$GRSAccount/groups/$GroupID"

        $membershipResult = Invoke-RestMethod -UseBasicParsing -Uri "https://$RSHost/grs/orgs/$GRSAccount/groups/$GroupID" -Method Get -Headers $grsHeader -ContentType $contentType -Body $body
        
        if($membershipResult.id -eq $GroupID) {
            Write-Output "Successfully retrieved '$GroupID' membership!"
        }
        else {
            Write-Output "Error retrieving '$GroupID' membership!"
        }

        return $membershipResult
    }
    catch {
        Write-Output "Error retrieving '$GroupID' membership! $($_ | Out-String)" 
    }
}

function Set-RSGroupMembership ($RSHost, $AccessToken, $GRSAccount, $GroupID, $userPayload) {
    try {
        Write-Output "Updating '$GroupID' membership..."
        
        $contentType = "application/json"
        
        $grsHeader = @{
            "X-API-Version"="2.0";
            "Authorization"="Bearer $AccessToken"
        }


        $membershipBodyPayload = [ordered]@{
            "group" = [ordered]@{
                "id" = $GroupID
                "href" = "/grs/orgs/$GRSAccount/groups/$GroupID"
                "kind" = "group"
            }
            "users" = @(
                $userPayload
            )
        } | ConvertTo-Json

        $membershipResult = Invoke-WebRequest -UseBasicParsing -Uri "https://$RSHost/grs/orgs/$GRSAccount/memberships" -Method Put -Headers $grsHeader -ContentType $contentType -Body $membershipBodyPayload
        
        if($membershipResult.StatusCode -eq "204") {
            Write-Output "Successfully updated '$GroupID' membership!"
        }
        else {
            Write-Output "Error updating '$GroupID' membership!"
        }
    }
    catch {
        Write-Output "Error updating '$GroupID' membership! $($_ | Out-String)" 
    }
}

$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}
$oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$REFRESH_TOKEN} | ConvertTo-Json
$oauthResult = Invoke-RestMethod -Uri "https://$RS_HOST/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $oauthBody
$accessToken = $oauthResult.access_token

$userPayload = @()

$membershipResult = Get-RSGroupMembership -RSHost $RS_HOST -AccessToken $accessToken -GRSAccount $GRS_ACCOUNT -GroupID $GROUP_ID
$existingUsers = $membershipResult.users

foreach ($existingUser in $existingUsers) {
    Write-Output "Found existing user: $($existingUser.email)"
    $object = New-Object -TypeName PSObject
    $object | Add-Member -MemberType NoteProperty -Name id -Value $existingUser.id 
    $object | Add-Member -MemberType NoteProperty -Name href -Value $existingUser.href
    $object | Add-Member -MemberType NoteProperty -Name kind -Value "user"
    $userPayload += $object
}

foreach ($UserID in $USER_IDS){
  #Write-Output "Adding new user to the org. User ID: $UserID"
  #rsc --refreshToken $REFRESH_TOKEN --host $RS_HOST --account $RS_ACCOUNT cm15 create permissions permission["user_href"]="/api/users/$UserID" permission["role_title"]="observer"
  $object = New-Object -TypeName PSObject
  $object | Add-Member -MemberType NoteProperty -Name id -Value $UserID
  $object | Add-Member -MemberType NoteProperty -Name href -Value "/grs/users/$UserID"
  $object | Add-Member -MemberType NoteProperty -Name kind -Value "user"
  $userPayload += $object
}

write-output $userPayload

$userPayload = $userPayload | Sort-Object -Unique -Property id

Set-RSGroupMembership -RSHost $RS_HOST -AccessToken $accessToken -GRSAccount $GRS_ACCOUNT -GroupID $GROUP_ID -userPayload $userPayload 

<#
foreach ($UserID in $USER_IDS){
    Write-Output "Revoking temporary, explicit observer access for user $UserID"
    $roles = rsc --refreshToken $REFRESH_TOKEN --host $RS_HOST --account $RS_ACCOUNT cm15 index permissions filter[]=user_href==/api/users/$UserID | convertfrom-json
    $observer_permissions = $roles | where role_title -eq "observer"
    foreach ($perm in $observer_permissions) { 
        if ($($perm.links | where rel -eq account).href -eq "/api/accounts/$RS_ACCOUNT") { 
            $temp_perm_href = $($perm.links | where rel -eq self).href 
        } 
    }
    rsc --refreshToken $REFRESH_TOKEN --host $RS_HOST --account $RS_ACCOUNT cm15 destroy $temp_perm_href
}  
#>