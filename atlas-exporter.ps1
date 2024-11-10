#!/usr/bin/pwsh
param(
    [string]$Measurement = 2006, 
    [string]$Probe = 51221,
    [switch]$Latest,
    [string]$Key = "974baae9-750a-427a-be78-e20797d6bbc4",
    [Int]$RateLimitSeconds = 86400,
    [string]$LokiUrl = "http://loki.nuc.home.arpa:3100/loki/api/v1/push"
)

Set-Location $PSScriptRoot
$AddInterval = [Int]($RateLimitSeconds / (./asap.ps1 -Api /api/v2/measurements/$Measurement/ -Key $Key).interval)
if ($Latest)
{
    $Result = ./asap.ps1 -Api /api/v2/measurements/$Measurement/latest/?probe_ids=$Probe -Key $Key
}
else
{
    $Result = ./asap.ps1 -Api /api/v2/measurements/$Measurement/results/?probe_ids=$Probe -Key $Key
}

if ($Result[0].type -eq "ntp")
{
    $Factor = 1000
}
else
{
    $Factor = 1
}

$cnt = $AddInterval
$values = New-Object System.Collections.ArrayList
$Result | ForEach-Object {
    if ($cnt -eq $AddInterval)
    {
        $null = $values.Add(@(
            [string]($_.timestamp * 1000000000),
            [string]((($_.result.rtt | Sort-Object -Descending)[0] * $Factor))
        ))
        $cnt = 0
    }
    $cnt++
}

if ($values.Count -gt 5000)
{
    Write-Host "There are $($values.Count) values, but Grafana only supports a maximum of 5000."
    return 1
}

$body =
@{
    streams =
    @(
        @{
            stream =
            @{
                label = "atlas"
                msm_id = "$Measurement"
                prb_id = "$Probe"
            }
            values = $values
        }
    )
} | ConvertTo-Json -Depth 5
Write-Host $body

Write-Host "There are $($values.Count) values"

Invoke-RestMethod -Method Post -Uri $LokiUrl -ContentType "application/json" -Body $body
