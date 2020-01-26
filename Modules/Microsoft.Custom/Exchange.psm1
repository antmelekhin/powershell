function Get-ExchCmdlets {
    <#
    .SYNOPSIS
    Функция загрузки командлетов Exchange в локальную сессию администратора.

    .EXAMPLE
    Get-ExchCmdlets -ServerName exch-01
    Загружает все командлеты с сервера exch-01 в локальную сессию администратора.

    .EXAMPLE
    Get-ExchCmdlets -ServerName exch-01 -ExchCmdlets Get-Mailbox, Set-Mailbox
    Загружает командлеты Get-Mailbox и Set-Mailbox с сервера exch-01 в локальную сессию администратора.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$ServerName
        ,
        [String[]]$ExchCmdlets
    )

    Process {
        # Подключаемся к серверу Exchange.
        $ExchSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ServerName/PowerShell/" -Authentication Kerberos

        # Формируем хэш-таблицу с параметрами для дальнейшей передачи их в командлет Import-PSSession.
        $SessionParameters = @{
            Session      = $ExchSession
            AllowClobber = $true
        }

        if ($PSBoundParameters.ContainsKey('ExchCmdlets')) {
            $SessionParameters.Add('CommandName', $ExchCmdlets)
        }

        # Загружаем командлеты в локальную сессию администратора.
        $null = Import-Module (Import-PSSession @SessionParameters) -Global
    }
}

function Get-ExchDatabase {
    <#
    .SYNOPSIS
    Функция получения информации о базе данных Exchange (Имя и объём).
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server
    )

    Process {
        [System.Collections.ArrayList]$DatabaseResults = @()
        foreach ($Database in (Get-MailboxDatabase -Server $Server -Status)) {

            # Создаём и наполняем объект свойствами.
            $DatabaseObject = [PSCustomObject]@{
                DatabaseName = $Database.Name
                DatabaseSize = $Database.DatabaseSize.Split('^(.*bytes$')[2].replace(',', '') / 1024 / 1024 -as [Int]
            }

            # Сохраняем все объекты в массив для вывода на экран.
            $null = $DatabaseResults.Add($DatabaseObject)
        }
    }

    End {
        # Вывод результатов на экран.
        $DatabaseResults
    }
}