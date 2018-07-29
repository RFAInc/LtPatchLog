<#
.DESCRIPTION
   Finds the patching LabTech log file given a computername. 
.EXAMPLE
   $temp = Get-Content computers.txt | Get-LtPatchingFile | Import-LtPatchingLog
.INPUTS
   Inputs to this cmdlet can be a list of Windows computer hostnames or IPs.
.OUTPUTS
   Output from this cmdlet is a io.fileinfo object.
#>
function Get-LtPatchingFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    Param
    (
        [Parameter(ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [Alias('Name', '__SERVER', 'CN', 'Computer')]
        [string[]]
        $ComputerName = $env:COMPUTERNAME
    )

    Begin {
        # Establish common/initial parameter values
        $WmiSplat = @{
            Class        = 'Win32_Service'
            Filter       = "Name='LtService'"
            ComputerName = $null
        }
    }
    Process {
        Foreach ($Computer in $ComputerName) {
            # Set the target device (local OK)
            $WmiSplat.Set_Item('ComputerName', $Computer)
            #Get the path from local POV
            $AgentLocalParentPath = (Get-WmiObject @WmiSplat).PathName.Trim() -replace '\\LtSvc\.exe\s.*'
            # Add file name to path for FullName
            $LocalLogPath = Join-Path $AgentLocalParentPath 'LtPatching.txt'
            # Convert to SMB Path
            $SmbLogPath = if ($Computer -ne $env:COMPUTERNAME) {
                "\\$($Computer)\$($LocalLogPath -replace ':','$')"
            }
            else {
                $LocalLogPath
            }#$SmbLogPath = if ($Computer -ne $env:COMPUTERNAME) {
            # Write object to pipeline
            Get-Item $SmbLogPath
        }#Foreach ($Computer in $ComputerName) {
    }
    End {
    }
}
<#
.DESCRIPTION
   Imports log entries from a specificly formatted LabTech log file. 
.EXAMPLE
   $temp = Get-LtPatchingFile | Import-LtPatchingLog
.INPUTS
   Inputs to this cmdlet come from the Get-LtPatchingFile function.
.OUTPUTS
   Output from this cmdlet is a psobject that can be consumed by other functions where noted.
#>
function Import-LtPatchingLog {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]
        [Alias('FullName')]
        $Path
    )

    Begin {
        $ptnLtPatchingLogLine = '(\w+?)\s\sv(\d{3}\.\d{3})\s\s\-\s(\d{1,2}\/\d{1,2}\/20\d{2}\s\d{1,2}:\d{2}:\d{2}\s[AP]M)\s\s-\s(.+?):::'
    }
    Process {
        Foreach ($FullName in $Path) {

            # Pull apart the Full Path to grab the computername
            $Computer = if ($FullName -match '^\\\\') {
                $FullName -replace '^\\\\' -replace '\\.*'
            }
            else {$env:COMPUTERNAME}

            # Get the log content
            $LogContent = Get-Content $FullName

            # Match the content, line by line
            $i = 1
            Foreach ($line in $LogContent) {
                $Groups = [regex]::Match($line, $ptnLtPatchingLogLine).Groups
                New-Object psobject -Property @{
                    LineNumber    = $i
                    ComputerName  = $Computer
                    Service       = [string](($Groups | Where-Object {$_.Name -eq 1}).Value)
                    Version       = [version](($Groups | Where-Object {$_.Name -eq 2}).Value)
                    TimeGenerated = [datetime](($Groups | Where-Object {$_.Name -eq 3}).Value)
                    Message       = [string](($Groups | Where-Object {$_.Name -eq 4}).Value)
                }#New-Object psobject -Property @{
                $i++
            }#Foreach ($line in $LogContent){
        }#Foreach ($item in $Path){
    }
    End {
    }
}
<#
.DESCRIPTION
Classifies log entries based on known messages. 
.EXAMPLE
$temp = Get-LtPatchingFile | Import-LtPatchingLog | Add-LtLogClassify
.INPUTS
Inputs to this cmdlet come from the Import-LtPatchingLog function.
.OUTPUTS
Output from this cmdlet is a psobject that can be consumed by other functions where noted.
#>
function Add-LtLogClassify {
    [CmdletBinding()]
    [OutputType([psobject])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [psobject]
        $InputObject
    )

    Begin {
        $dicMsgClass = @{
            InstallAttempt            = '(Attempting to install) patches: (.*)'
            noDaytimePatching         = '(Daytime patching) is (n?o?t?\s?enabled)'
            PolicySchedule            = 'Microsoft\sUpdate\sPolicy\s\-\sSchedule:\s(\w{2}\sat\s\d{1,2}[AP]M\-\d{1,2}[AP]M)\s\-\sOptions:\s(.*)$'
            PolicyScheduleWithOptions = 'Microsoft\sUpdate\sPolicy\s\-\sSchedule:\s(\w{2}\sat\s\d{1,2}[AP]M\-\d{1,2}[AP]M)\s\-\sOptions:\sBefore Script:\s([a-f\d\-]+?), After Script:\s([a-f\d\-]+?)$'
            PolicyUpdated             = '(Microsoft Update Policy)\s(settings updated)'
            InitManual                = '(Initiating manual) (patch u?n?install)'
            InitAuto                  = '(Initiating) (Microsoft Patch Job)'
            InitReboot                = 'Initiating\spatch reboot\.\s(Applied policy behavior):\s(.+?)$'
            GetPatches                = '(Getting)\s([\w\s]+?)\sPatches'
            NoWork                    = '(No Patch work) needs (to be done)'
            GetNextWindow             = 'Getting\snext\s([\w\s]+?)\swindow\s?f?o?r?\s?t?h?e?\s?(.*)\s?\.'
            NextWindowIs              = '(Next Window): (\d{1,2}\/\d{2}\/20\d{2}\s\d{1,2}[AP]M\-\d{1,2}[AP]M)'
            RebootRequired            = '(Patch) install (requires reboot)'
            RebootComplete            = '(Patch) (reboot complete)'
        }

        $keySet = $dicMsgClass.Keys
    }
    Process {
        Foreach ($record in $InputObject) {
            # $record = $InputObject[-3]

            # Capture the message text
            $Message = $record.Message

            # $Key = 'NextWindow'
            foreach ($Key in $keySet) {
                # $Key = 'GetNextWindow'

                # Set the pattern
                $ptnMsg = $dicMsgClass.Get_Item($Key)

                # Make me a match
                $MatchGroups = [regex]::Match($Message, $ptnMsg).Groups

                if ($MatchGroups[0].Success) {
                    $Class = $Key

                    switch ($Class) {
                        InstallAttempt {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#InstallAttempt
                        RebootRequired {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#RebootRequired
                        PolicyUpdated {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#PolicyUpdated
                        InitManual {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#InitManual
                        NoWork {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#NoWork
                        PolicyScheduleWithOptions {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#PolicyScheduleWithOptions
                        PolicySchedule {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#PolicySchedule
                        GetPatches {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#GetPatches
                        GetNextWindow {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#GetNextWindow
                        NextWindowIs {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#NextWindow
                        InitReboot {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#InitReboot
                        noDaytimePatching {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#noDaytimePatching
                        InitAuto {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#InitAuto
                        RebootComplete {
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#RebootComplete
                        Default {
                            # "This switch shouldn't have zero matches!...." -ErrorAction Inquire
                            Write-Warning "Unhandled Key: $($Class) - $($Message)"
                            $Type = $MatchGroups[1].Value
                            $Value = $MatchGroups[2].Value
                            $Data = $MatchGroups[3].Value
                        }#Default
                    }#switch ($MatchingKey)

                    $ClassSplat = @{
                        MemberType = 'NoteProperty'
                        Name       = 'Class'
                        Value      = $Class
                    }
                    $TypeSplat = @{
                        MemberType = 'NoteProperty'
                        Name       = 'Type'
                        Value      = $Type
                    }
                    $ValueSplat = @{
                        MemberType = 'NoteProperty'
                        Name       = 'Value'
                        Value      = $Value
                    }
                    $DataSplat = @{
                        MemberType = 'NoteProperty'
                        Name       = 'Data'
                        Value      = $Data
                    }

                    # Write the record to the pipeline
                    $record | Add-Member @ClassSplat
                    $record | Add-Member @TypeSplat
                    $record | Add-Member @ValueSplat
                    $record | Add-Member @DataSplat
                    Write-Output $record |
                        Sort-Object -Property LineNumber

                }#if ($MatchGroups[0].Success)
            }#foreach ($Key in $keySet)
        }#Foreach ($record in $InputObject)
    }
    End {
    }
}
<#
$temp =
    Get-LtPatchingFile |
        Import-LtPatchingLog |
        Add-LtLogClassify
$temp[0]
$Temp.Count
$temp|select timeg*,Class,Type,
    Value,Data,mess*|
    sort timeg* -desc|
    Out-GridView

#>

