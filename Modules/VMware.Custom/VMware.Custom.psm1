function Connect-vCenter {
    <#
    .SYNOPSIS
    Функция подключения к серверу vCenter.

    .DESCRIPTION
    Используется в других финкциях данного модуля для подключения к vCenter, если администратор не сделал этого заранее.
    #>
    $ReadHost = Read-Host -Prompt 'Хотите подключиться? (y/n)'
    switch ($ReadHost) {
        Y { $Server = Read-Host -Prompt 'Введите имя сервера'; $null = Connect-VIServer -Server $Server -Force }
        N { Write-Host -ForegroundColor Yellow 'Подключение прервано пользователем'; break script }
        Default { Write-Host -ForegroundColor Yellow 'Подключение прервано пользователем'; break script }
    }
}

function Get-HostedVM {
    <#
    .SYNOPSIS
    Функция сбора информации об одной или нескольких виртуальных машин VMWare.

    .EXAMPLE
    Get-HostedVM -Name MyVM
    Получаем информацию о виртуальной машине VMWare.

    .EXAMPLE
    Get-HostedVM
    Получаем информацию обо всех виртуальных машинах.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name
    )

    Begin {
        # Проверяем есть ли текущее подключение к vCenter, если нет - подключаемся.
        if (-not $global:DefaultVIServers) {
            Write-Host 'Вы не подключены ни к одному серверу vCenter. ' -NoNewline
            Connect-vCenter
        }
    }

    Process {
        # Создаём массив для наполнения его всеми объектами для дальнейшего вывода на экран.
        [System.Collections.ArrayList]$VMResults = @()

        # Перебираем указанные виртуальные машине, создаём и наполняем объект свойствами.
        foreach ($VM in (Get-VM @PSBoundParameters)) {
            $VMObject = [PSCustomObject]@{
                'Name'        = $VM.Name
                'Powerstate'  = $VM.Powerstate
                'Cluster'     = $VM.ResourcePool.Parent.Name
                'VMTools'     = $VM.Guest.ExtensionData.ToolsVersion
                'OSName'      = $VM.Guest.OSFullName
                'DNSName'     = $VM.Guest.HostName
                'Network'     = ($VM.Guest.ExtensionData.Net.Network | Select-Object -Unique) -join ', '
                'IPAddress'   = ($VM.Guest.IPAddress | Where-Object { $_ -match '\d{1,3}(\.\d{1,3}){3}' }) -join ', '
                'Datastore'   = $VM.ExtensionData.Config.DatastoreUrl.Name -join ', '
                'Description' = $VM.Notes -replace [Char]10, ', '
            }

            # Сохраняем все объекты в массив для вывода на экран.
            $null = $VMResults.Add($VMObject)
        }
    }

    End {
        # Вывод результатов на экран.
        $VMResults
    }
}

function Get-EsxiHost {
    <#
    .SYNOPSIS
    Функция сбора информации об одном или нескольких Esxi-хостах VMWare.

    .EXAMPLE
    Get-EsxiHost -Name MyHost
    Получаем информацию о Esxi хосте.

    .EXAMPLE
    Get-EsxiHost
    Получаем информацию обо всех хостах Esxi.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name
    )

    Begin {
        # Проверяем есть ли текущее подключение к vCenter, если нет - подключаемся.
        if (-not $global:DefaultVIServers) {
            Write-Host 'Вы не подключены ни к одному серверу vCenter. ' -NoNewline
            Connect-vCenter
        }
    }

    Process {
        # Создаём массив для наполнения его всеми объектами для дальнейшего вывода на экран.
        [System.Collections.ArrayList]$EsxiResults = @()

        # Перебираем указанные Esxi-хосты, создаём и наполняем объект свойствами.
        foreach ($Esxi in (Get-VMHost @PSBoundParameters)) {
            $EsxiObject = [PSCustomObject]@{
                'Name'       = $Esxi.Name
                'Hypervisor' = $Esxi.ExtensionData.Config.Product.FullName
                'Model'      = ($Esxi.Manufacturer + ' ' + $Esxi.Model)
                'Processor'  = $Esxi.ProcessorType
                'CPUNum'     = $Esxi.ExtensionData.Hardware.CpuInfo.NumCpuThreads
                'NicNum'     = $Esxi.NetworkInfo.PhysicalNic.Count
                'VMNum'      = $Esxi.ExtensionData.Vm.Count
                'State'      = $Esxi.ConnectionState
                'Cluster'    = $Esxi.Parent
            }

            # Сохраняем все объекты в массив для вывода на экран.
            $null = $EsxiResults.Add($EsxiObject)
        }
    }

    End {
        # Вывод результатов на экран.
        $EsxiResults
    }
}