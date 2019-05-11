Import-Module -Name "$PSSCriptRoot\switchesdboard.psm1"
. "$PSSCriptRoot\pages\home.ps1"

$configfile = Get-Item -Path ".\config\network.json"
$EndpointInit = New-UDEndpointInitialization -Function @("Get-NetworkConf","") -Variable @("configFile")
$Schedule5Min = New-UDEndpointSchedule -Every 5 -Minute
$udepNetworkConf = New-UDEndpoint -Schedule $Schedule5Min -Endpoint {
    $Cache:SwitchesCount = 0
    $Cache:NetworkConf = $(Get-NetworkConf -Path $configfile)
    $Cache:SwitchesCount = $Cache:NetworkConf.switches.count
}
$SwitchesDashboard = New-UDDashboard -Title 'Switches Dashboard' -Pages @($udpageHome) -EndpointInitialization $EndpointInit
$Server = Start-UDDashboard -Port 1001 -Dashboard $SwitchesDashboard -Endpoint $udepNetworkConf
