# atlas-wont-let-me-rest

RIPE Atlas公式の[REST API](https://atlas.ripe.net/docs/apis/rest-api-reference/)を素早く使えるようにするヘルパースクリプト。  
[RIPE-NCC/ripe-atlas-tools](https://github.com/RIPE-NCC/ripe-atlas-tools)では物足りないが、時間を溶かしたくない人。あるいは頻回の2FAで腱鞘炎になった人向け。

## Usage

必要なpermissionが分からない場合、API Keyに全permissionを与える初期設定も行う
```powershell
./asap.ps1 -Init
```
apikeyファイルを置かない場合
```powershell
./asap.ps1 -Api /api/v2/measurements/ -Key XXXX-XXX-XXX-XXXX
```
Hiddenも含めて自分のMeasurementsをVSCodeに表示
```powershell
(./asap.ps1 -Api "/api/v2/measurements/my/?sort=-start_time&hidden=true").results | code -
```

自分のProbe IDを取得
```powershell
$MyProbes = (./asap.ps1 -Api /api/v2/probes/my/?hidden=true).results[0].id
$MyProbes
```
Probe IDを指定して取得したping measurementsを表にする
```powershell
$Result = ./asap.ps1 -Api /api/v2/measurements/{msm_id}/results/?probe_ids=$MyProbes
$Result | Format-Table -Property @{Label = "timestamp"; Expression = {
    [TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds($_.timestamp), [TimeZoneInfo]::FindSystemTimeZoneById('Asia/Tokyo'))
}}, min, avg, max
```
```
timestamp                   min  avg   max
---------                   ---  ---   ---
07/05/2024 12:49:03 +09:00 6.23 6.50  6.74
07/06/2024 00:49:06 +09:00 5.99 6.09  6.26
07/06/2024 12:49:06 +09:00 6.43 6.62  6.75
07/07/2024 00:49:04 +09:00 5.98 6.12  6.22
07/07/2024 12:49:03 +09:00 6.01 6.31  6.48
...
```

NTP measurements
```powershell
$Result | Sort-Object timestamp | Format-Table @{l="rtt";e={$_.result.rtt}}, @{Label = "timestamp"; Expression = {
    [TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds($_.timestamp), [TimeZoneInfo]::FindSystemTimeZoneById('Asia/Tokyo'))
}} | code -
```

既存のmeasurementsに特定のProbeを追加  
https://atlas.ripe.net/docs/apis/rest-api-manual/participation_requests.html
```powershell
$MyProbes = (./asap.ps1 -Api /api/v2/probes/my/?hidden=true).results[0].id
./asap.ps1 -Method Post -Api /api/v2/measurements/{msm_id}/participation-requests/ -Body @"
[{
    "type": "probes",
    "action": "add",
    "requested": 1,
    "value": "$MyProbes"
}]
"@
```
```
request_ids
-----------
{request_ids}
```
```
# 確認
./asap.ps1 -Api /api/v2/participation-requests/{request_ids}/
```

https://atlas.ripe.net/probes/{prb_id}/#tab-udms 相当。  
自分のProbeのUser Defined Measurementsを見たいときに。
```powershell
$MyProbesUDM = [System.Collections.ArrayList]@()
$cnt = 1
do
{
    $Page = ./asap.ps1 -Api ("/api/v2/probes/$MyProbes/measurements/" + ($cnt -eq 1 ? "" : "?page=$cnt"))
    $MyProbesUDM += $Page.results
    $cnt++
} while ($Page.next -ne $null)
$MyProbesUDM | Format-Table id, type, target, status, start_time
```
```
id                           type                         target                      status                      start_time
--                           ----                         ------                      ------                      ----------
1004732                      Traceroute6                  www.google.com              Ongoing                     11/29/2012 08:54:25
1014622                      DNS                                                      Ongoing                     07/31/2013 08:05:49
1040113                      Ping                         bits.wikimedia.org          Ongoing                     11/15/2013 15:39:51
1040114                      Ping6                        bits.wikimedia.org          Ongoing                     11/15/2013 15:41:22
1040120                      Ping                         bits-lb.esams.wikimedia.org Ongoing                     11/15/2013 15:48:52
...
```
既存のmeasurementsから特定のProbeを削除
```powershell
# description欄をまず探す
$PartsMsm = $MyProbesUDM | Where-Object target -match "8.8.8.8"

# 無ければ当該measurements typeで絞って再帰クエリする
$PartsMsm = $MyProbesUDM | Where-Object {$_.type -eq "Ping" -And $_.status -eq "Ongoing" -And $_.target -notmatch "ripe.net"}
```
```powershell
$PartsMsm.id | ForEach-Object {
    ./asap.ps1 -Method Post -Api /api/v2/measurements/$_/participation-requests/ -Body @"
[{
    "type": "probes",
    "action": "remove",
    "requested": 1,
    "value": "$($MyProbes.results[0].id)"
}]
"@
}
```

特定の権限を持つAPIキーを取得

```powershell
./asap.ps1 -Method Post -Api /api/v2/keys/ -Body @"
{
    "label": "test",
    "grants": [
        {
            "permission": "measurements.list_measurements"
        },
        {
            "permission": "measurements.get_measurement",
            "target": {
                "id": "mail@example.com",
                "type": "user"
            }
        }
    ]
}
"@
```
