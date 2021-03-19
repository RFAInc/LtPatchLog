# LtPatchLog
Tools for parsing the ltpatching log file in LabTech (Automate)

# Examples

## Get the local computer's patching log content
```
[Net.ServicePointManager]::SecurityProtocol=[enum]::GetNames([Net.SecurityProtocolType])|Foreach-Object{[Net.SecurityProtocolType]::$_}; (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/RFAInc/LtPatchLog/master/LtPatchLog.psm1') | Invoke-Expression; Get-LtPatchingFile | Import-LtPatchingLog | ft -a -wrap
```
