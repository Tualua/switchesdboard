function Get-SwitchFDBCisco
{
  param (
    [string]$IPAddress,
    [string[]]$IgnoreIf,
    [int]$MinVLAN = 1,
    [int]$MaxVLAN = 1000
  )
  $swNumber = [int]$($IPAddress.Substring($IPAddress.LastIndexOf('.')+1,$IPAddress.Length-$IPAddress.LastIndexOf('.')-1))
  $dot1dTpFdbPort = '.1.3.6.1.2.1.17.4.3.1.2'
  $dot1dBasePortIfIndex = '.1.3.6.1.2.1.17.1.4.1.2'
  $vtpVlanState = '.1.3.6.1.4.1.9.9.46.1.3.1.1.2.1'
  $ifName = '.1.3.6.1.2.1.31.1.1.1.1'
  $FDB = @()
  $MACAddresses = @()
  $SleepTimer = 100
    
     
    
  $ip = [ipaddress]::Parse($IPAddress)
  $svr = New-Object System.Net.IpEndPoint ($ip, 161)
       
  $ver = [Lextm.SharpSnmpLib.VersionCode]::V2
  $walkMode = [Lextm.SharpSnmpLib.Messaging.WalkMode]::WithinSubtree
  $maxRepetitions = 10
    
  $swIfNames = New-Object 'System.Collections.Generic.List[Lextm.SharpSnmpLib.Variable]'
  $oid = New-Object Lextm.SharpSnmpLib.ObjectIdentifier ($ifName)
  try 
  {
    [Lextm.SharpSnmpLib.Messaging.Messenger]::BulkWalk($ver, $svr, 'public', $oid, $swIfNames, 10000, $maxRepetitions, $walkMode, $null, $null)|Out-Null
  } 
  catch [Lextm.SharpSnmpLib.Messaging.TimeoutException]
  {
    Write-Error "SNMP Timeout connecting to $svr"
      
  }
  catch {
    Write-Error "SNMP Walk error: $_"
       
  }
  $tableSwIfNames = @{}
  ForEach ($swIfName in $swIfNames)
  {
    $tableSwIfNames.Add($($swIfName.Id).ToString().SubString($ifName.Length),$($swIfName.Data).ToString())
  }
    
  $oid = New-Object Lextm.SharpSnmpLib.ObjectIdentifier ($vtpVlanState)
  $swVlans = New-Object 'System.Collections.Generic.List[Lextm.SharpSnmpLib.Variable]'
  try 
  {
    [Lextm.SharpSnmpLib.Messaging.Messenger]::BulkWalk($ver, $svr, 'public', $oid, $swVlans, 10000, $maxRepetitions, $walkMode, $null, $null)|Out-Null
  } 
  catch [Lextm.SharpSnmpLib.Messaging.TimeoutException]
  {
    Write-Error "SNMP Timeout connecting to $svr"
      
  }
  catch {
    Write-Error "SNMP Walk error: $_"
       
  }
    
  foreach ($vlan in $swVlans)
  {
    $vlanid = [int]$($vlan.id).ToString().SubString($vtpVlanState.Length)
    If (($vlanid -le $MaxVLAN) -and ($vlanid -ge $MinVLAN))
    {
      
      $oid = $dot1dBasePortIfIndex
      $swMappings = New-Object 'System.Collections.Generic.List[Lextm.SharpSnmpLib.Variable]'
      try 
      {
        [Lextm.SharpSnmpLib.Messaging.Messenger]::BulkWalk($ver, $svr, $('public@',$vlanid -join ''), $oid, $swMappings, 10000, $maxRepetitions, $walkMode, $null, $null)|Out-Null
      } 
      catch [Lextm.SharpSnmpLib.Messaging.TimeoutException]
      {
        Write-Error "SNMP Timeout connecting to $svr getting info for VLAN $vlanid"
      }
      catch 
      {
        Write-Error "SNMP Walk error: $_"
      }
      $tableSwMappings = @{}
      ForEach ($mapping in $swMappings)
      {
        $tableSwMappings.Add($($mapping.Id).ToString().SubString($dot1dBasePortIfIndex.Length),$($mapping.Data).ToString())
      }
      
      Start-Sleep -Milliseconds $SleepTimer
      $vlanFDBPortTemp = New-Object 'System.Collections.Generic.List[Lextm.SharpSnmpLib.Variable]'
      $oid = $dot1dTpFdbPort
      try 
      {
        [Lextm.SharpSnmpLib.Messaging.Messenger]::BulkWalk($ver, $svr, $('public@',$vlanid -join ''), $oid, $vlanFDBPortTemp, 10000, $maxRepetitions, $walkMode, $null, $null)|Out-Null
      } 
      catch [Lextm.SharpSnmpLib.Messaging.TimeoutException]
      {
        Write-Error "SNMP Timeout connecting to $svr getting info for VLAN $vlanid"
      }
      catch 
      {
        Write-Error "SNMP Walk error: $_"
      } 
      If ($vlanFDBPortTemp.Count -gt 0)
      {
        ForEach ($FDBItem in $vlanFDBPortTemp)
        {
            
          $InterfaceName = $tableSwIfNames[$($tableSwMappings["$($FDBItem.Data)"])]
          If (!($IgnoreIf.Contains($InterfaceName)))
          {
            $MACaddrDec = @()
            $MACAddrHex = @()
            $MACaddrDec =$($FDBItem.Id).ToString().Substring(23).Split('.')
            ForEach ($octet in $MACaddrDec)
            {
              $MacAddrHex += '{0:X2}' -f [int]$octet
            }
            $MACAddr = $MacAddrHex -join ":"
            
            $InterfaceNumber = [int]$($tableSwMappings["$($FDBItem.Data)"])-10000
            If ($InterfaceNumber -gt 100)
            {
              $InterfaceNumber = $InterfaceNumber-100+48
            }
            $MACAddresses += [PSCustomObject]@{
              swNumber = $swNumber
              ifNumber = $InterfaceNumber
              macaddr = $MACAddr
              ifName = $InterfaceName
              VID = $vlanid
            }
          }
        }
         
      }
    } 
  }
      
    
  return $MACAddresses
}
function Get-SwitchFDBDLink
{
  param(
    [string]$IPAddress,
    [int[]]$IgnoreIf = @(),
    [int]$MinVLAN = 1,
    [int]$MaxVLAN = 1000
  )
  $swNumber = [int]$($IPAddress.Substring($IPAddress.LastIndexOf('.')+1,$IPAddress.Length-$IPAddress.LastIndexOf('.')-1))
  $oiddot1qTpFdbEntry = ".1.3.6.1.2.1.17.7.1.2.2.1.2"
  $ip = [ipaddress]::Parse($IPAddress)
  $svr = New-Object System.Net.IpEndPoint ($ip, 161)
       
  $ver = [Lextm.SharpSnmpLib.VersionCode]::V2
  $walkMode = [Lextm.SharpSnmpLib.Messaging.WalkMode]::WithinSubtree
  $maxRepetitions = 10
  $MACAddresses = @()    
  $tempFDB = New-Object 'System.Collections.Generic.List[Lextm.SharpSnmpLib.Variable]'
  $oid = New-Object Lextm.SharpSnmpLib.ObjectIdentifier ($oiddot1qTpFdbEntry)
  try 
  {
    [Lextm.SharpSnmpLib.Messaging.Messenger]::BulkWalk($ver, $svr, 'public', $oid, $tempFDB, 10000, $maxRepetitions, $walkMode, $null, $null)|Out-Null
  } 
  catch [Lextm.SharpSnmpLib.Messaging.TimeoutException]
  {
    Write-Error "SNMP Timeout connecting to $svr"
      
  }
  catch 
  {
    Write-Error "SNMP Walk error: $_"       
  }
  ForEach ($FDBItem in $tempFDB)
  {
            
    $InterfaceNumber = [int]$($FDBItem.Data.ToString())
    $MACVLAN = $($FDBItem.Id).ToString().Substring($oiddot1qTpFdbEntry.Length)
    $vlanid = [int]$MACVLAN.Split('.')[0]
    If ((!($IgnoreIf.Contains($InterfaceNumber))) -and ($InterfaceNumber -gt 0) -and ($vlanid -ge $MinVLAN) -and ($vlanid -le $MaxVLAN))
    {
      $MACaddrDec = @()
      $MACAddrHex = @()
              
      $MACaddrDec = $MACVLAN.Substring($MACVLAN.IndexOf('.')+1,$MACVLAN.Length - $MACVLAN.IndexOf('.') - 1).Split('.')
      ForEach ($octet in $MACaddrDec)
      {
        $MacAddrHex += '{0:X2}' -f [int]$octet
                
      }
      $MACAddr = $MacAddrHex -join ":"
                          
      $MACAddresses += [PSCustomObject]@{
        swNumber = $swNumber
        ifNumber = $InterfaceNumber
        macaddr = $MACAddr
        ifName = $InterfaceNumber
        VID = $vlanid
      }
    }
  }
  return $MACAddresses
}function Get-TimeSpanFromMikrotikTimeString
{
  #Content
  param
  (
    [Parameter(Mandatory=$true)][string]
    $timestring  
  )
  $regex = [regex] '((\d+)w)?((\d+)d)?((\d+)h)?((\d+)m)?((\d+)s)?((\d+)ms)?'
  $regexResult = [regex]::Match($timestring,$regex)
  [TimeSpan]$tsUptime = ([TimeSpan]::MinValue)

  If ($regexResult) 
  {
    [double]$ms = 0
    For ($i=1; $i -lt $regexResult.Groups.Count; $i += 2)
    {
      If (![string]::IsNullOrEmpty($regexResult.Groups[$i].Value))
      {
        [double]$value = [double]$regexResult.Groups[$i+1].Value
        If 
        ($regexResult.Groups[$i].Value.EndsWith('w'))
        {
          $ms += $value * 604800000
        }
        ElseIf
        ($regexResult.Groups[$i].Value.EndsWith('d'))
        {
          $ms += $value * 86400000
        }
        ElseIf
        ($regexResult.Groups[$i].Value.EndsWith('h'))
        {
          $ms += $value * 3600000
        }
        ElseIf
        ($regexResult.Groups[$i].Value.EndsWith('m'))
        {
          $ms += $value * 60000
        }
        ElseIf
        ($regexResult.Groups[$i].Value.EndsWith('s'))
        {
          $ms += $value * 1000
        }
        ElseIf
        ($regexResult.Groups[$i].Value.EndsWith('ms'))
        {
          $ms += $value
        }

      }
    
    }
    $tsUptime = [TimeSpan]::FromMilliseconds($ms)
    return $tsUptime    
  }
}
function Get-DHCPLeaseProperty
{
  param
  (
    [Parameter(Mandatory=$true)][string]
    $LeaseString,

    [Parameter(Mandatory=$true)][string]
    $Property    
  )
  If ($LeaseString.IndexOf($Property) -gt -1)
  {
    $step1 = $LeaseString.Substring($LeaseString.IndexOf($Property),$LeaseString.Length-$LeaseString.IndexOf($Property))
    If ($step1.Length)
    {
      $step2 = $step1.Substring($Property.Length+1,$step1.IndexOf('=',$Property.Length+1)-($Property.Length+1))
    }
    Else
    {
      $step2 = $null
    }
  }
  Else
  {
    $step2 = $null
  }
  return $step2
}
function Get-DHCPActiveLeases
{
  param
  (
    [Parameter(Mandatory=$true)][string]
    $RouterIPAddress,

    [Parameter(Mandatory=$true)][string]
    $UserName,

    [Parameter(Mandatory=$true)][string]
    $Password
  )
  $Connection = Connect-Mikrotik -IPaddress $RouterIPAddress -UserName $UserName -Password $Password -UseSSL
  $DHCPLeasesRaw = (Send-Mikrotik -Connection $Connection -Command '/ip/dhcp-server/lease/getall') -split "`r`n"
  Disconnect-Mikrotik -Connection $Connection
  $Leases= @()
  ForEach ($lease in $DHCPLeasesRaw)
  {
    $hostname = Get-DHCPLeaseProperty -LeaseString $lease -Property 'host-name'
    $IPAddress = Get-DHCPLeaseProperty -LeaseString $lease -Property 'active-address'

    If ($IPAddress)
    {
      $MinerProperties = @{
        HostName = $hostname
        IPAddress = $IPAddress
        MACAddress = (Get-DHCPLeaseProperty -LeaseString $lease -Property 'active-mac-address')
        LastSeen = Get-TimeSpanFromMikrotikTimeString -timestring (Get-DHCPLeaseProperty -LeaseString $lease -Property 'last-seen')
      }
      $Leases+= (New-Object -TypeName PSCustomObject -Property $MinerProperties)
    }

  }

  $NormalLeases = @()
  $tableLeases = @{}
  $NormalLeases = ($Leases | Group-Object -Property MACAddress |Where-Object -FilterScript {$_.Count -eq 1}|Select-Object -ExpandProperty Group)
  $DuplicateLeases = @()
  $DuplicateLeases += ($Leases | Group-Object -Property MACAddress |Where-Object -FilterScript {$_.Count -gt 1})
  ForEach ($grp in $DuplicateLeases)
  {
    $minv = ($grp | Select-Object -ExpandProperty Group | Measure-Object -Property LastSeen -Minimum ).Minimum
    $NormalLeases += $grp|Select-Object -ExpandProperty Group | Where-Object {$_.LastSeen -eq $minv}
  }
  ForEach ($lease in $NormalLeases)
  {
    $tableLeases.Add($lease.MACAddress,$lease.IPAddress)
  }
  
  #return $NormalLeases | Sort-Object -Property { [Version] $_.IPAddress}
  return $tableLeases
}
function Get-ASICInfo
{
  param (
    [string]$IPAddress
  )
  $port = 4028
  $command = '{"command":"stats","parameter":"0"}'
  $commandDelay = 100
  
  try
  {
    
    $socket = new-object System.Net.Sockets.TcpClient($IPAddress, $port)
    
  }
  catch
  {
    $result = [psCustomObject]@{Type = 'Unknown'}
  }
  If ($socket)
  {
    $stream = $socket.GetStream()
    $writer = new-object System.IO.StreamWriter $stream
    $writer.WriteLine($command)
    $writer.Flush()
    Start-Sleep -m $commandDelay
    $buffer = new-object System.Byte[] 1024
    $encoding = new-object System.Text.AsciiEncoding
    $outputBuffer = @()
    $foundMore = $false
    Do
    {
      ## Allow data to buffer for a bit
      Start-Sleep -m 10
        
      ## Read what data is available
      $foundmore = $false
      $stream.ReadTimeout = 1000        
      Do
      {
        try
        {
          $read = $stream.Read($buffer, 0, 1024)
                
          if($read -gt 0)
          {
            $foundmore = $true
            $outputBuffer += ($encoding.GetString($buffer, 0, $read))
          }
        } catch { $foundMore = $false; $read = 0 }
      } while($read -gt 0)
    } while($foundmore)
    If ($outputBuffer)
    {
      $result = $($($outputBuffer -replace '}{','},{') -replace "`0", "" | ConvertFrom-Json|Select -ExpandProperty stats)[0]
    }
    Else
    {
      $result = [psCustomObject]@{Type = 'Unknown'}
    }
  }
  return $result #| Add-Member -MemberType NoteProperty -Name 'ipaddr' -Value $IPAddress
}
function Get-NetworkConf
{
  $sw = Get-Content -Path $(Join-Path -Path $PSScriptRoot -ChildPath 'network.json')|ConvertFrom-Json
  return $sw
}
