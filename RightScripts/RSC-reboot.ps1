#reboot RL10 instance using RSC to invoke decommission scripts
#authenticate with oauth refresh token ($env:REFRESH_TOKEN)
#$env:RS_ENDPOINT = rightscale endpoint - ie. us-3.rightscale.com

$erroractionpreference = 'stop'
$indexInstance = rsc --rl10 cm15 index_instance_session /api/sessions/instance
$selfHref = (($indexInstance | ConvertFrom-Json).Links | where rel -eq self).href


rsc --pp --refreshToken $env:REFRESH_TOKEN --host $env:RS_ENDPOINT cm15 reboot "$selfHref/reboot"
