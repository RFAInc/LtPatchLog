# LtPatchLog
Tools for parsing the ltpatching log file in LabTech (Automate)

# Examples

## Get the local computer's patching log content
```
[Net.ServicePointManager]::SecurityProtocol=[enum]::GetNames([Net.SecurityProtocolType])|Foreach-Object{[Net.SecurityProtocolType]::$_}; (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/RFAInc/LtPatchLog/master/LtPatchLog.psm1') | Invoke-Expression; Get-LtPatchingFile | Import-LtPatchingLog | ft -a -wrap
```

## Raise a warning message if no log entries for past 2 days
```
$Now = Get-Date; [Net.ServicePointManager]::SecurityProtocol=[enum]::GetNames([Net.SecurityProtocolType])|Foreach-Object{[Net.SecurityProtocolType]::$_}; (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/RFAInc/LtPatchLog/master/LtPatchLog.psm1') | Invoke-Expression; $Last = Get-LtPatchingFile | Import-LtPatchingLog | Sort TimeGenerated | Select -expand TimeGenerated -Last 1; if ($Now.AddDays(-2) -gt $Last) {Write-Warning "No log Entries for 2 or more days!"}
```
