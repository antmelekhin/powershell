function Get-ComputerLastBootTime {
    <#
    .SYNOPSIS
    Функция сбора информации о последнем времени загрузки компьютера.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [String[]]$ComputerName
    )

    if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
        $PSBoundParameters.ComputerName = $env:COMPUTERNAME
    }

    [System.Collections.ArrayList]$ComputerResults = @()
    foreach ($Computer in (Get-WmiObject -ClassName Win32_OperatingSystem @PSBoundParameters)) {
        $ComputerObject = [PSCustomObject]@{
            'ComputerName' = $Computer.CSName
            'LastBootTime' = $Computer.ConvertToDateTime($Computer.LastBootUpTime)
        }
        $null = $ComputerResults.Add($ComputerObject)
    }
    $ComputerResults
}

function Get-LocalDisk {
    <#
    .SYNOPSIS
    Функция сбора информации о дисках локального или удалённого компьютера.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [String[]]$ComputerName
    )

    if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
        $PSBoundParameters.ComputerName = $env:COMPUTERNAME
    }

    [System.Collections.ArrayList]$DiskResults = @()
    foreach ($Disk in (Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3' @PSBoundParameters)) {
        $DiskObject = [PSCustomObject]@{
            'DiskID'    = $Disk.DeviceID
            'FullSize'  = '{0:N1} Gb' -f (($Disk | Measure-Object -Property Size -Sum).Sum / 1Gb)
            'FreeSpace' = '{0:N1} Gb' -f (($Disk | Measure-Object -Property FreeSpace -Sum).Sum / 1Gb)
        }
        $null = $DiskResults.Add($DiskObject)
    }
    $DiskResults
}