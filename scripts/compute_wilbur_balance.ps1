$ErrorActionPreference = 'Stop'
$usersPath = 'e:\forage-midas\src\test\resources\test_data\lkjhgfdsa.hjkl'
$txPath = 'e:\forage-midas\src\test\resources\test_data\alskdjfh.fhdjsk'

$names = @{}
$balances = @{}
$i = 1
$users = Get-Content -LiteralPath $usersPath
Write-Output "UsersCount=$($users.Length)"
$users | ForEach-Object {
  $parts = $_.Split(',')
  $name = $parts[0].Trim()
  $rawBal = $parts[1].Trim()
  Write-Output "rawBal='$rawBal'"
  $bal = [float]$rawBal
  $names[$i] = $name
  $balances[$i] = $bal
  Write-Output "Loaded: id=$i name=$name bal=$bal"
  $i++
}

$wilburId = ($names.GetEnumerator() | Where-Object { $_.Value -eq 'wilbur' }).Key
Write-Output "WilburId=$wilburId"
Write-Output "WilburInitial=$($balances[$wilburId])"

$txs = Get-Content -LiteralPath $txPath
foreach ($line in $txs) {
  $p = $line.Split(',')
  $senderId = [int]$p[0].Trim()
  $recipientId = [int]$p[1].Trim()
  $amount = [float]$p[2].Trim()
  if ($amount -le 0) { continue }
  if (-not $balances.ContainsKey($senderId) -or -not $balances.ContainsKey($recipientId)) { continue }
  if ($balances[$senderId] -lt $amount) { continue }

  $bodyObj = [pscustomobject]@{ senderId = [long]$senderId; recipientId = [long]$recipientId; amount = $amount }
  $body = $bodyObj | ConvertTo-Json -Compress
  try {
    $resp = Invoke-RestMethod -Method Post -Uri 'http://localhost:8080/incentive' -ContentType 'application/json' -Body $body
    $incentive = 0.0
    if ($null -ne $resp -and $null -ne $resp.amount) { $incentive = [float]$resp.amount; if ($incentive -lt 0) { $incentive = 0 } }
  } catch {
    $incentive = 0.0
  }

  $balances[$senderId] = $balances[$senderId] - $amount
  $balances[$recipientId] = $balances[$recipientId] + $amount + $incentive
}

Write-Output "WilburFinal=$($balances[$wilburId])"