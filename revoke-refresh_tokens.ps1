param(
  $US3_ACCOUNT = "",
  $US4_ACCOUNT = "", 
  $USER_ID = "",
  $US3_REFRESH_TOKEN = "", 
  $US4_REFRESH_TOKEN = "" 
)

$contentType = "application/json"
$oauthHeader = @{"X_API_VERSION"="1.5"}

$US3oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$US3_REFRESH_TOKEN} | ConvertTo-Json
$US3oauthResult = Invoke-RestMethod -Uri "https://us-3.rightscale.com/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $US3oauthBody
$US3accessToken = $US3oauthResult.access_token
$US3grsHeader = @{"X-API-Version"="2.0";"Authorization"="Bearer $US3accessToken"}
$US3Header = @{"Authorization"="Bearer $US3accessToken"}

$US4oauthBody = @{"grant_type"="refresh_token";"refresh_token"=$US4_REFRESH_TOKEN} | ConvertTo-Json
$US4oauthResult = Invoke-RestMethod -Uri "https://us-4.rightscale.com/api/oauth2" -Method Post -Headers $oauthHeader -ContentType $contentType -Body $US4oauthBody
$US4accessToken = $US4oauthResult.access_token
$US4grsHeader = @{"X-API-Version"="2.0";"Authorization"="Bearer $US4accessToken"}
$US4Header = @{"Authorization"="Bearer $US4accessToken"}

$orgs = Invoke-RestMethod -UseBasicParsing -Uri "https://us-3.rightscale.com/grs/users/$USER_ID/orgs" -Method Get -Headers $US3grsHeader -ContentType $contentType

$projects = @()
foreach ($org in $orgs){
  $uri = "https://us-3.rightscale.com"+$org.links.projects.href
  $project = Invoke-RestMethod -UseBasicParsing -Uri $uri -Method Get -Headers $US3grsHeader -ContentType $contentType
  $object = New-Object -TypeName PSObject
  $object | Add-Member -MemberType NoteProperty -Name org_name -Value $org.name
  $object | Add-Member -MemberType NoteProperty -Name org_id -Value $org.id
  $object | Add-Member -MemberType NoteProperty -Name org_href -Value $org.href
  $object | Add-Member -MemberType NoteProperty -Name project_name -Value $project.name
  $object | Add-Member -MemberType NoteProperty -Name project_id -Value $project.id 
  $object | Add-Member -MemberType NoteProperty -Name project_href -Value $project.href 
  $object | Add-Member -MemberType NoteProperty -Name project_url -Value $project.legacy.account_url
  $projects += $object
}

foreach ($project in $projects){
  Write-Output ""
  Write-Output "Org Name: $($project.org_name)"
  Write-Output "Number of Projects: $($project.project_id.count)"
  Write-Output "Project Names: "
  Write-Output $($project.project_name)
  $cont = Read-Host -Prompt "Continue? (y/n)"
  if ($cont -ne "y") {
    Write-Output "Skipping Org.."
    continue 
  }
  foreach ($proj_url in $project.project_url) {
    if (($($proj_url.split("/")[5]) -ne $US3_ACCOUNT) -and ($($proj_url.split("/")[5]) -ne $US4_ACCOUNT)){
      if ($proj_url.split(".")[0].split("-")[1] -eq "3"){
        Invoke-WebRequest -UseBasicParsing -Uri "https://us-3.rightscale.com/acct/$($proj_url.split("/")[5])/accounts/$($proj_url.split("/")[5])/revoke_oauth" -Method Post -Headers $US3Header
      } elseif ($proj_url.split(".")[0].split("-")[1] -eq "4"){
        Invoke-WebRequest -UseBasicParsing -Uri "https://us-4.rightscale.com/acct/$($proj_url.split("/")[5])/accounts/$($proj_url.split("/")[5])/revoke_oauth" -Method Post -Headers $US4Header
      } else {
        Write-Output "ERROR: Shard not Identified"
      }
    } else {
      Write-Output "Account ID: $($proj_url.split("/")[5])"
      Write-Output "Skipping.."
    }
  }
}