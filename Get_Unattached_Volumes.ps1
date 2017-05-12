#script assumes that rsc.exe is in the working directory
$email = "" # email address associated with RS user
$password = "" # RS password
$endpoint = "" # us-3.rightscale.com -or- us-4.rightscale.com
$account = "" # RS account number

$clouds = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index clouds | convertfrom-json

$all_vol = @()
foreach ($cloud in $clouds) {                                                                              
    $vol = @()
    $vol = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index $($cloud.links | where rel -eq volumes).href | ConvertFrom-Json
    $all_vol += $vol 
}         

$unattached = @()
foreach ($vol in $all_vol) { 
    if (($vol.links | where rel -eq current_volume_attachment) -eq $null) { 
        $unattached += $vol 
    }
}                                              
$unattached | Export-Csv ".\$account-unattached-volumes.csv"  