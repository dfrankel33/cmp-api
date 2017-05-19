#script assumes that rsc.exe is in the working directory
$token = Read-Host "Enter RS Refresh Token" # API Refresh Token
$endpoint = Read-Host "Enter RS API endpoint (us-3.rightscale.com -or- us-4.rightscale.com)" # us-3.rightscale.com -or- us-4.rightscale.com
$account = Read-Host "Enter RS Account Number" # RS account number

$account = $account.Trim()
$clouds = ./rsc --refreshToken $token --host $endpoint --account $account cm15 index clouds | convertfrom-json

$all_vol = @()
foreach ($cloud in $clouds) {
    if ($($cloud.links | Where-Object rel -eq volumes)) {                                                                              
        $vol = @()
        $vol = ./rsc --refreshToken $token --host $endpoint --account $account cm15 index $($cloud.links | Where-Object rel -eq volumes).href | ConvertFrom-Json
        $all_vol += $vol 
    }
}         

$unattached = @()
foreach ($vol in $all_vol) { 
    if (($vol.status -eq "available") -and ($vol.resource_uid -notlike "*system@Microsoft.Compute/Images/*") -and ($vol.resource_uid -notlike "*@images*")) { 
        $unattached += $vol 
    }
}                                              
$unattached | Select-Object name,description,resource_uid,size,status,created_at,updated_at,cloud_specific_attributes,@{name="href";expression={$($_.links | Where-Object rel -eq "self").href}} | Export-Csv "./$account-unattached-volumes.csv"  
