#!/usr/bin/pwsh
param(
    [switch]$Init,
    [string]$Key = (Get-Content ./apikey),
    [string]$KeyLabel = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss"),
    [string]$Api = '/api/v2/measurements/my/?sort=-start_time&hidden=true'
)

function Get-ResponseOrStatus
{
    param(
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = 'Get',
        [string]$ContentType = 'application/json',
        [string]$Api,
        [hashtable]$Body
    )

    Write-Host "$Method $Api"

    try
    {
        if ($Body)
        {
            $Response = Invoke-RestMethod -Method $Method -ContentType $ContentType -Headers @{ "Authorization" = "Key $Key" } -Body ($Body | ConvertTo-Json -Depth 100) -Uri "https://atlas.ripe.net$Api"
        }
        else
        {
            $Response = Invoke-RestMethod -Method $Method -ContentType $ContentType -Headers @{ "Authorization" = "Key $Key" } -Uri "https://atlas.ripe.net$Api"
        }
    }
    catch
    {
        Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
        return $_.Exception.Response.StatusCode.value__
    }
    return $Response
}

if ($Init)
{
    # API Keyの更新に必要な権限があるか確認
    $KeyPerm = Get-ResponseOrStatus -Api "/api/v2/keys/$Key/"
    if ($KeyPerm -eq 403)
    {
        Write-Host 'After setting the minimum authorization "keys.get_key", "keys.update_key" for the API Key at https://atlas.ripe.net/, you can rest.'
        return
    }
    elseif ($KeyPerm -match "^\d{3}$")
    {
        Write-Host 'Rest only after setting up the API Key.'
        return
    }
    elseif ("keys.update_key" -notin $KeyPerm.grants.permission )
    {
        Write-Host 'After setting the minimum authorization "keys.update_key" for the API Key at https://atlas.ripe.net/, you can rest.'
        return
    }

    # 権限一覧権限を取得
    Get-ResponseOrStatus -Method Patch -Api "/api/v2/keys/$key/" -Body @{
        label = $KeyLabel
        grants =
        [System.Collections.ArrayList]@(
            @{
                permission = "keys.list_permissions"
            },
            @{
                permission = "keys.list_permission_targets"
            }
        ) + $KeyPerm.grants
    }

    # 全てを知る
    $AvailableKeyPerm = New-Object System.Collections.ArrayList
    $AvailableKeyPerm = Get-ResponseOrStatus -Api '/api/v2/keys/permissions/'

    $Grants = New-Object System.Collections.ArrayList
    $AvailableKeyPerm.results | Select-Object -Property @{Label = "permission"; Expression = {$_.id}}, @{Label = 'target'; Expression = {
        if (![string]::IsNullOrEmpty($_.target_types))
        {
            return (Get-ResponseOrStatus -Api "/api/v2/keys/permissions/$($_.id)/targets/").results[0] | Select-Object -Property id, type
        }}
    } | ForEach-Object {
        # 出力は寛容に、入力は厳密に
        if ($_.target -eq $null)
        {
            $Grants.Add(@{
                permission = $_.permission
            }) > $null
        }
        else {
            $Grants.Add($_) > $null
        }
    } 

    # 全てを与える
    Get-ResponseOrStatus -Method Patch -Api "/api/v2/keys/$key/" -Body @{
        label = $KeyLabel
        grants = $Grants
    }
}

return Get-ResponseOrStatus -ContentType $ContentType -Api $Api
