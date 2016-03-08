#set servername variable
$servername = read-host "Input server name"

$clouds = rsc --refreshToken="abcd...wxyz" cm15 index /api/clouds --host="us-3.rightscale.com"
$cloudhrefs = (($clouds | ConvertFrom-Json).links | where rel -eq self).href

foreach ($cloudhref in $cloudhrefs) {
    if (!$instance) {
        $instance = rsc --refreshToken="abcd..wxyz" cm15 index "$cloudnum/instances" "filter[]=name==$servername" --host="us-3.rightscale.com"
    }
}

$instancehref = ((($instance | ConvertFrom-Json) | where state -eq provisioned).links | where rel -eq self).href

#start instance
rsc --refreshToken="abcd...wxyz" cm15 start $instancehref --host="us-3.rightscale.com"

#stop instance
#rsc --refreshToken="abcd...wxyz" cm15 stop $instancehref --host="us-3.rightscale.com"
