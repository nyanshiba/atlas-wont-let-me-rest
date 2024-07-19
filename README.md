# atlas-wont-let-me-rest

RIPE Atlas公式の[REST API](https://atlas.ripe.net/docs/apis/rest-api-reference/)を素早く使えるようにするヘルパースクリプト。  
[RIPE-NCC/ripe-atlas-tools](https://github.com/RIPE-NCC/ripe-atlas-tools)では物足りないが、時間を溶かしたくない人。あるいは頻回の2FAで腱鞘炎になった人向け。

## Usage

```powershell
# Hiddenも含めて自分のProbeを表示
./asap.ps1 -Api /api/v2/probes/my/?hidden=true
# Hiddenも含めて自分のMeasurementsを表示
./asap.ps1 -Api "/api/v2/measurements/my/?sort=-start_time&hidden=true"

# 必要なpermissionが分からない場合、API Keyに全permissionを与える初期設定も行う
./asap.ps1 -Init -Api /api/v2/measurements/

# apikeyファイルを置かない場合
./asap.ps1 -Api /api/v2/measurements/ -Key XXXX-XXX-XXX-XXXX
```
