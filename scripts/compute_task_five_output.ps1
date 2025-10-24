$ErrorActionPreference = 'Stop'
$usersPath = 'e:\forage-midas\src\test\resources\test_data\lkjhgfdsa.hjkl'
$txPath = 'e:\forage-midas\src\test\resources\test_data\rueiwoqp.tyruei'

$balances = @{}
$i = 1
Get-Content -LiteralPath $usersPath | ForEach-Object {
  $parts = $_.Split(',')
  $name = $parts[0].Trim()
  $rawBal = $parts[1].Trim()
  $bal = [float]$rawBal
  $balances[$i] = $bal
  $i++
}

# Process transactions with validation like TransactionService
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
  } catch { $incentive = 0.0 }

  $balances[$senderId] = $balances[$senderId] - $amount
  $balances[$recipientId] = $balances[$recipientId] + $amount + $incentive
}

# Build output block exactly like TaskFiveTests
$output = @()
$output += "---begin output ---"
for ($j = 0; $j -lt 13; $j++) {
  if ($balances.ContainsKey($j)) {
    $amt = $balances[$j]
  } else {
    $amt = [float]0
  }
  $output += "Balance {amount=$amt}"
}
$output += "---end output ---"
$output -join "`n"