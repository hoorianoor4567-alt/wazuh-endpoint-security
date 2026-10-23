# Tests File Integrity Monitoring on C:\InterneeData
# Expected: rule 554 (added), 550 (modified), 553 (deleted)
New-Item -ItemType Directory -Path C:\InterneeData -Force | Out-Null
"hello internee" | Out-File C:\InterneeData\test.txt
Start-Sleep 10
"changed content" | Out-File C:\InterneeData\test.txt
Start-Sleep 10
Remove-Item C:\InterneeData\test.txt
Write-Host "Done. Check Dashboard > File Integrity Monitoring > Events."
