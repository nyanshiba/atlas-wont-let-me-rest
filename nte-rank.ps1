#!/usr/bin/pwsh
param(
    [string]$Probe = 51221,
    [string]$Measurement = 5006, # m.root-servers.net
    [string]$Start = (Get-Date -Date ((Get-Date).AddMonths(-6)) -UFormat "%s"), # 半年前
    [string]$Stop = (Get-Date -UFormat "%s"),
    [string]$Key = "974baae9-750a-427a-be78-e20797d6bbc4",
    [string]$IPTTL = 2
)

Set-Location $PSScriptRoot

# Traceroute計測結果から2ホップ目を取得し
$NTEResults = @()
$Results = ./asap.ps1 -Api "/api/v2/measurements/$Measurement/results/?probe_ids=$Probe&start=$Start&stop=$Stop" -Key $Key
foreach ($r in $Results)
{
    $NTEResults += $r.result.Where({$_.hop -eq $IPTTL}).result
}

# NTE毎に集計
$NTEIPs = $NTEResults.from | Sort-Object -Unique
foreach ($f in $NTEIPs)
{
    $RTTs = $NTEResults.Where({$_.from -eq $f}).rtt | Sort-Object
    Write-Output "$f latency min: $($RTTs[0]), 50%ile: $($RTTs[($RTTs.Count * 0.5)]), 90%ile: $($RTTs[($RTTs.Count * 0.9)]), 95%ile: $($RTTs[($RTTs.Count * 0.95)])"
}
