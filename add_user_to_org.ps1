param(
  $RS_HOST = "us-3.rightscale.com",
  $GRS_ORG = "",
  $USER_IDS = @(""), 
  $REFRESH_TOKEN = "",
  $ROLE_TITLE = "billing_center_viewer",
  $REVOKE_USER_IDS = @("") 
)

function Add-OrgUser ($RS_HOST, $ACCESS_TOKEN, $GRS_ORG, $USER_ID) {
    try {
        Write-Output "Adding User (ID: $USER_ID) to Org $GRS_ORG..."
        
        $contentType = "application/json"
        
        $grsHeader = @{
            "X-API-Version"="2.0";
            "Authorization"="Bearer $ACCESS_TOKEN"
        }

        $userPayload = [ordered]@{
            "id" = $USER_ID
            "href" = "/grs/users/$USER_ID"
            "kind" = "user"
        } | ConvertTo-Json

        $membershipResult = Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/users" -Method Post -Headers $grsHeader -ContentType $contentType -Body $userPayload
        
        if($membershipResult.StatusCode -eq "201") {
            Write-Output "Successfully added user!"
        }
        else {
            Write-Output "Error adding user!"
        }
    }
    catch {
        Write-Output "Error adding user! $($_ | Out-String)" 
    }
}

function Grant-UserPermission ($RS_HOST, $ACCESS_TOKEN, $GRS_ORG, $USER_ID, $ROLE_HREF) {
    try {
        Write-Output "Granting Role ($ROLE_HREF) to User (ID: $USER_ID)..."
        
        $contentType = "application/json"
        
        $grsHeader = @{
            "X-API-Version"="2.0";
            "Authorization"="Bearer $ACCESS_TOKEN"
        }

        $grantPayload = [ordered]@{
            "subject" = [ordered]@{
                "href" = "/grs/users/$USER_ID"
            }
            "role"= [ordered]@{
                "href" = $ROLE_HREF
            }
        } | ConvertTo-Json

        $grantResult = Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/access_rules/grant" -Method Put -Headers $grsHeader -ContentType $contentType -Body $grantPayload
        
        if($grantResult.StatusCode -eq "204") {
            Write-Output "Successfully granted user role!"
        }
        else {
            Write-Output "Error granting user role!"
        }
    }
    catch {
        Write-Output "Error granting user role! $($_ | Out-String)" 
    }
}

function Revoke-UserPermission ($RS_HOST, $ACCESS_TOKEN, $GRS_ORG, $USER_ID, $ROLE_HREF) {
    try {
        Write-Output "Revoking Role ($ROLE_HREF) from User (ID: $USER_ID)..."
        
        $contentType = "application/json"
        
        $grsHeader = @{
            "X-API-Version"="2.0";
            "Authorization"="Bearer $ACCESS_TOKEN"
        }

        $grantPayload = [ordered]@{
            "subject" = [ordered]@{
                "href" = "/grs/users/$USER_ID"
            }
            "role"= [ordered]@{
                "href" = $ROLE_HREF
            }
        } | ConvertTo-Json

        $grantResult = Invoke-WebRequest -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/access_rules/revoke" -Method Put -Headers $grsHeader -ContentType $contentType -Body $grantPayload
        
        if($grantResult.StatusCode -eq "204") {
            Write-Output "Successfully revoked user role!"
        }
        else {
            Write-Output "Error revoking user role!"
        }
    }
    catch {
        Write-Output "Error revoking user role! $($_ | Out-String)" 
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
$rolesResult = Invoke-RestMethod -UseBasicParsing -Uri "https://$RS_HOST/grs/orgs/$GRS_ORG/roles" -Method Get -Headers $grsHeader -ContentType $contentType
$roleHref = ($rolesResult | Where-Object name -eq $ROLE_TITLE).href

foreach ($UserID in $USER_IDS){
    # Associate Users with Org
    Add-OrgUser -RS_HOST $RS_HOST -ACCESS_TOKEN $accessToken -GRS_ORG $GRS_ORG -USER_ID $UserID
    # Grant enterprise_manager role
    Grant-UserPermission -RS_HOST $RS_HOST -ACCESS_TOKEN $accessToken -GRS_ORG $GRS_ORG -USER_ID $UserID -ROLE_HREF $roleHref
}

if ($REVOKE_USER_IDS){
    foreach ($UserID in $REVOKE_USER_IDS){
        Revoke-UserPermission -RS_HOST $RS_HOST -ACCESS_TOKEN $accessToken -GRS_ORG $GRS_ORG -USER_ID $UserID -ROLE_HREF $roleHref
    }
}