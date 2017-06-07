#script assumes that rsc.exe is in the working directory
$email = Read-Host "Enter RS email address" # email address associated with RS user
#$pass = Read-Host "Enter RS Password" -AsSecureString # RS password
$password = Read-Host "Enter RS Password"
$endpoint = Read-Host "Enter RS API endpoint (us-3.rightscale.com -or- us-4.rightscale.com)" # us-3.rightscale.com -or- us-4.rightscale.com
$accounts = Read-Host "Enter RS Account Number(s) (comma-separated if multiple)" # RS account number
$customer_name = Read-Host "Enter Customer Name"

#$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($pass)
#$password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
#[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

if ($accounts -like "*,*") {
    $accounts = $accounts.Split(",")
}

$total_unattached = @()
foreach ($account in $accounts) {
    $account = $account.Trim()
    $clouds = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index clouds | convertfrom-json

    $all_vol = @()
    foreach ($cloud in $clouds) {
        if ($($cloud.links | Where-Object rel -eq volumes)) {                                                                              
            $vol = @()
            $vol = .\rsc.exe --email $email --pwd $password --host $endpoint --account $account cm15 index $($cloud.links | Where-Object rel -eq volumes).href | ConvertFrom-Json
            $all_vol += $vol 
        }
    }         

    $unattached = @()
    foreach ($vol in $all_vol) { 
        if (($vol.status -eq "available") -and ($vol.resource_uid -notlike "*system@Microsoft.Compute/Images/*") -and ($vol.resource_uid -notlike "*@images*")) { 
            $unattached += $vol 
        }
    }                                              
    $total_unattached += $unattached | Select-Object @{name="account_number";expression={$account}},name,description,resource_uid,size,status,created_at,updated_at,cloud_specific_attributes,@{name="href";expression={$($_.links | Where-Object rel -eq "self").href}} #| Export-Csv "./$account-unattached-volumes.csv"  
}

$total_unattached | Export-Csv "./$customer_name-unattached-volumes.csv"