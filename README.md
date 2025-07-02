# atlas-wont-let-me-rest

RIPE Atlas公式の[REST API](https://atlas.ripe.net/docs/apis/rest-api-reference/)を素早く使えるようにするヘルパースクリプト。  
[RIPE-NCC/ripe-atlas-tools](https://github.com/RIPE-NCC/ripe-atlas-tools)では物足りないが、時間を溶かしたくない人。あるいは頻回の2FAで腱鞘炎になった人向け。

## asap.ps1

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

## atlas-exporter.ps1

[Loki HTTP API](https://grafana.com/docs/loki/latest/reference/loki-http-api/)に対応したExporter。  
[可視化はGrafanaでって言ったよね - 俺の外付けHDD](http://localhost:3000/blog/grafana#ripe-atlas)

初期値を設定すると、引数から省略できる。  
GrafanaのLine limitを考慮して、デフォルトでは86400秒間隔にログを選んで送信するよう設定されている。
```ps1
param(
    [string]$Measurement = 2006, 
    [string]$Probe = 51221,
    [switch]$Latest,
    [string]$Key = "974baae9-750a-427a-be78-e20797d6bbc4",
    [Int]$RateLimitSeconds = 86400,
    [string]$LokiUrl = "http://loki.nuc.home.arpa:3100/loki/api/v1/push"
)
```
これまでのログをすべてLokiに送信
```powershell
./ntpm.ps1 -Measurement 2006
```
毎日、最新の計測を送信
```sh:crontab
5 5 * * * /usr/bin/pwsh /home/user/atlas/ntpm.ps1 -Measurement <msm_id> -Latest
```

## nte-rank.ps1

NTEガチャの指標に。管理下のProbeや、フレッツ系の単県ISPなどProbeのゲートウェイがPPPoEに向いている前提。
- 当たりNTEの例
```
198.51.100.249 latency min: 5.375, 50%ile: 6.006, 90%ile: 7.051, 95%ile: 11.608
198.51.100.251 latency min: 5.389, 50%ile: 6.012, 90%ile: 6.825, 95%ile: 11.816
203.0.113.251 latency min: 5.466, 50%ile: 6.09, 90%ile: 8.958, 95%ile: 13.762
```
- 外れNTEの例
```
203.0.113.168 latency min: 6.25, 50%ile: 6.688, 90%ile: 12.095, 95%ile: 14.188
198.51.100.248 latency min: 5.486, 50%ile: 6.061, 90%ile: 8.564, 95%ile: 15.166
203.0.113.103 latency min: 5.606, 50%ile: 6.675, 90%ile: 10.117, 95%ile: 15.882
203.0.113.137 latency min: 6.073, 50%ile: 6.597, 90%ile: 14.505, 95%ile: 16.768
198.51.100.250 latency min: 5.387, 50%ile: 6.032, 90%ile: 9.44, 95%ile: 19.105
198.51.100.252 latency min: 5.438, 50%ile: 6.16, 90%ile: 19.636, 95%ile: 48.676
```
[Yamaha RTXのLuaスクリプト](https://nyanshiba.com/blog/yamahartx-settings#luaで自動nninteガチャ)や[NEC IXのネットワークモニタ機能](https://nyanshiba.com/blog/nec-ix#nteガチャ)に投入して使える。

```powershell
# Probe 51221の、過去1年間(既定6ヵ月)のm.root-servers.net組み込みTraceroute計測を取得し、2ホップ目を集計する例
.\nte-rank.ps1 -Probe 51221 -Measurement 5006 -Start (Get-Date -Date ((Get-Date).AddYears(-1)) -UFormat "%s") -Key "974baae9-750a-427a-be78-e20797d6bbc4" -IPTTL 2
```
