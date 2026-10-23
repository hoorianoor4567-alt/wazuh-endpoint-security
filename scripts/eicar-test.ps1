# Creates the harmless EICAR antivirus test file in the FIM-watched folder.
# The string is split so this script itself is not flagged by antivirus.
# Requires a temporary Defender exclusion:  Add-MpPreference -ExclusionPath "C:\InterneeData"
# Expected: rule 100200 (level 13). Afterwards remove the file and the exclusion.
$a = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR'
$b = '-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
Set-Content -Path C:\InterneeData\eicar.com -Value ($a + $b) -NoNewline -Encoding Ascii
(Get-FileHash C:\InterneeData\eicar.com -Algorithm MD5).Hash
