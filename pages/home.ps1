$udlayoutHome = New-UDLayout -Columns 1 -Content {
    New-UDCounter -Title "Switches" -Endpoint {
        $Cache:SwitchesCount
    }
    
}
$udpageHome = New-UDPage -Name 'Home' -Content {
    $udlayoutHome
}
