# LtPatchLog
Tools for parsing the ltpatching log file in LabTech (Automate)

# Examples

## Find the latest version of Windows 10 (Semi-Annual Channel)
```
[Net.ServicePointManager]::SecurityProtocol=[enum]::GetNames([Net.SecurityProtocolType])|Foreach-Object{[Net.SecurityProtocolType]::$_}; (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/RFAInc/LtPatchLog/develop/LtPatchLog.psm1?token=AEV5QIBV772QAS5N3HBOJELAKTOQK') | Invoke-Expression; Get-LtPatchingFile | Import-LtPatchingLog
```
