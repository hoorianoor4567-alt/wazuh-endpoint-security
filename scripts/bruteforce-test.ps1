# Simulates failed logons for a non-existent user.
# Type any wrong password each time it asks.
# Expected: rule 60122 for each failure, then rule 100100 (level 12)
for ($i = 1; $i -le 3; $i++) {
    Write-Host "Attempt $i of 3"
    runas /user:hacker cmd
}
Write-Host "Done. Search 'rule.id:100100' in Threat Hunting."
