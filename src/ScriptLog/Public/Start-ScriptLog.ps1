using namespace System.Collections

function Start-ScriptLog {
    [CmdletBinding(
        DefaultParameterSetName = 'Path',
        HelpUri = 'https://go.thomasnieto.com/Start-ScriptLog'
    )]
    [OutputType([LogMessage])]
    param (
        [Parameter(
            ParameterSetName = 'Path',
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(
            ParameterSetName = 'OutputDirectory',
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputDirectory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [PSObject]
        $ScriptInfo,

        [Parameter()]
        [IDictionary]
        $BoundParameters,

        [Parameter()]
        [switch]
        $NoEnvironmentInfo,

        [Parameter()]
        [switch]
        $NoClobber,

        [Parameter()]
        [switch]
        $Append,

        [Parameter()]
        [switch]
        $PassThru
    )

    $scriptLogInfo = [ScriptLogInfo]::New($true, $true)
    $scriptLogInfo.BoundParameters = $BoundParameters

    if ($PSBoundParameters['ScriptInfo']) {
        $scriptLogInfo.ScriptName = $ScriptInfo.Name
        $scriptLogInfo.ScriptVersion = $ScriptInfo.Version
        $scriptLogInfo.ScriptPath = $ScriptInfo.Path
    }

    if (-not $PSBoundParameters['Path']) {
        # A random string is used to match Start-Transcript default file name
        $randomBytes = New-Object -TypeName Byte[] -ArgumentList 6
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
        $randomString = [Convert]::ToBase64String($randomBytes) -replace '/', '_'

        if ($PSBoundParameters['ScriptInfo']) {
            $fileName = $LocalizedData.DefaultScriptFullName -f $ScriptInfo.Name, [Environment]::MachineName, $randomString, (Get-Date)
        }
        else {
            $fileName = $LocalizedData.DefaultScriptFullName -f $LocalizedData.DefaultScriptName, [Environment]::MachineName, $randomString, (Get-Date)
        }

        if ($PSBoundParameters['OutputDirectory']) {
            $Path = Join-Path -Path $OutputDirectory -ChildPath $fileName
        }
        else {
            $Path = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath $fileName
        }
    }

    $scriptLogInfo.Path = $Path
    
    if ($NoClobber -and -not $Append -and (Test-Path -Path $scriptLogInfo.Path)) {
        $paramWriteError = @{
            Message      = ($LocalizedData.FileExistsNoClobber -f $scriptLogInfo.Path)
            Category     = 'ResourceExists'
            TargetObject = $scriptLogInfo.Path
        }
        
        Write-Error @paramWriteError
    }

    $header = @()
    $header += Get-Padding -String $LocalizedData.ScriptLogStartHeader

    foreach ($item in $scriptLogInfo.PSEnvironment.GetEnumerator()) {
        if ($item.Key -eq 'StartTime' -or $item.Key -eq 'EndTime') {
            $value = $item.Value.ToString($script:DATETIMEFORMAT)
        }
        else {
            $value = $item.Value
        }

        $header += '{0} = {1}' -f $item.Key, $Value
    }

    if (-not $NoEnvironmentInfo) {
        $header += Get-Padding -String $LocalizedData.EnvironmentHeader
        $header += '{0} = {1}' -f 'Host', $Host.Name
        
        foreach ($item in $PSVersionTable.GetEnumerator()) {
            $header += '{0} = {1}' -f $item.Key, ($item.Value -join ', ')
        }
    }

    if ($PSBoundParameters['ScriptInfo'] -or $PSBoundParameters['BoundParameters']) {
        $header += Get-Padding -String $LocalizedData.ScriptInvocationHeader
    }

    if ($PSBoundParameters['ScriptInfo']) {
        $scriptProperties = $scriptLogInfo |
        Get-Member -Name Script* -MemberType Property |
        Select-Object -ExpandProperty Name
        
        foreach ($property in $scriptProperties) {
            $header += '{0} = {1}' -f $property, $scriptLogInfo.$property
        }
    }

    if ($PSBoundParameters['BoundParameters']) {
        foreach ($item in $scriptLogInfo.BoundParameters.GetEnumerator()) {
            $key = 'ScriptParameter_{0}' -f $item.Key
            $invocation[$key] = $item.Value

            $header += '{0} = {1}' -f $key, $item.Value
        }
    }

    $header += $LocalizedData.DividerCharacter * $LocalizedData.DividerLength

    if ($Append) {
        Add-Content -Value $header -Path $scriptLogInfo.Path
    }
    else {
        Set-Content -Value $header -Path $scriptLogInfo.Path
    }

    if ($PassThru) {
        Write-Output -InputObject $scriptLogInfo
    }
}
