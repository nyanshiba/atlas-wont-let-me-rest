#!/usr/bin/pwsh
param(
    [string]$Measurement = 2006, 
    [string]$Probe = 51221,
    [switch]$Latest,
    [string]$Key = "974baae9-750a-427a-be78-e20797d6bbc4",
    [Int]$RateLimitSeconds = 86400,
    [string]$LokiUrl = "http://loki.home.arpa:3100/loki/api/v1/push",
    [string[]]$HopLimits = (2, 5, 10)
)

Set-Location $PSScriptRoot

# 最後の計測だけ取得
if ($Latest)
{
    $Response = ./asap.ps1 -Api /api/v2/measurements/$Measurement/latest/?probe_ids=$Probe -Key $Key
}
# 全ての計測
else
{
    $Response = ./asap.ps1 -Api /api/v2/measurements/$Measurement/results/?probe_ids=$Probe -Key $Key
}

# Lokiに送るラベルを定義
$body = @{}
$body.streams = New-Object System.Collections.ArrayList
if ($Response[0].type -eq "traceroute")
{
    foreach ($h in $HopLimits)
    {
        $null = $body.streams.Add(@{
            stream = @{
                label = "atlas"
                msm_id = "$Measurement"
                prb_id = "$Probe"
                hop = "$h"
            }
            values = New-Object System.Collections.ArrayList
        })
    }
}
else
{
    $null = $body.streams.Add(@{
        stream = @{
            label = "atlas"
            msm_id = "$Measurement"
            prb_id = "$Probe"
        }
        values = New-Object System.Collections.ArrayList
    })
}

# NTPは秒をミリ秒に直す
$Factor = $Response[0].type -eq "ntp" ? 1000 : 1

# Lokiに送る計測を選出する頻度
$AddInterval = [Int]($RateLimitSeconds / (./asap.ps1 -Api /api/v2/measurements/$Measurement/ -Key $Key).interval)
# 計測値を追加
$cnt = $AddInterval
$Response | ForEach-Object {
    if ($cnt -eq $AddInterval)
    {
        if ($_.type -eq "traceroute")
        {
            foreach ($h in $_.result.Where({$_.hop -In $HopLimits}))
            {
                $null = ($body.streams | Where-Object {$_.stream.hop -eq $h.hop}).values.Add(@(
                    [string]($_.timestamp * 1000000000),
                    [string]((($h.result.rtt | Sort-Object -Descending)[0] * $Factor))
                ))
            }
        }
        else
        {
            $null = $body.streams[0].values.Add(@(
                [string]($_.timestamp * 1000000000),
                [string]((($_.result.rtt | Sort-Object -Descending)[0] * $Factor))
            ))
        }
        $cnt = 0
    }
    $cnt++
}

$bodyJson = $body | ConvertTo-Json -Depth 5
Write-Host $bodyJson

if ($values.Count -gt 5000)
{
    Write-Host "There are $($values.Count) values, but Grafana only supports a maximum of 5000."
    return 1
}
else
{
    Write-Host "There are $($values.Count) values"
}

Invoke-RestMethod -Method Post -Uri $LokiUrl -ContentType "application/json" -Body $bodyJson
