# atlas-wont-let-me-rest

RIPE Atlas公式の[REST API](https://atlas.ripe.net/docs/apis/rest-api-reference/)を素早く使えるようにするヘルパースクリプト。  
[RIPE-NCC/ripe-atlas-tools](https://github.com/RIPE-NCC/ripe-atlas-tools)では物足りないが、時間を溶かしたくない人。あるいは頻回の2FAで腱鞘炎になった人向け。

## Usage

```powershell
Hiddenも含めて自分のProbeを表示
```powershell
./asap.ps1 -Api /api/v2/probes/my/?hidden=true
```
Hiddenも含めて自分のMeasurementsをVSCodeに表示
```powershell
./asap.ps1 -Api "/api/v2/measurements/my/?sort=-start_time&hidden=true" | code -
```
必要なpermissionが分からない場合、API Keyに全permissionを与える初期設定も行う
```powershell
./asap.ps1 -Init -Api /api/v2/measurements/
```
apikeyファイルを置かない場合
```powershell
./asap.ps1 -Api /api/v2/measurements/ -Key XXXX-XXX-XXX-XXXX
```
ping measurementsを表にする
```powershell
$Result = ./asap.ps1 -Api /api/v2/measurements/<msm_id>/results/?probe_ids=<prb_id>
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