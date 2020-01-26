function Get-InactiveADComputerAccounts {
    <#
    .SYNOPSIS
    Функция получения устаревших аккаунтов компьютеров в Active Directory.

    .PARAMETER NumberOfDays
    Параметр для указания количества дней, которое прошло с момента последнего подключения аккаунта компьютера к домену.

    .PARAMETER SearchBase
    Параметр для указания организационной единицы, в которой осуществляется поиск устаревших аккаунтов. Если не указан, то поиск осуществляется во всём домене.

    .EXAMPLE
    Get-InactiveADComputerAccounts -NumberOfDays 120 -SearchBase 'OU=Workstations,OU=Company,DC=Domain,DC=Local' | Remove-ADComputer
    Получаем аккаунты компьютеров в организационной единице 'OU=Workstations,OU=Company,DC=Domain,DC=Local', которые неактивны в течение 120 дней и удаляем их.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [Int]$NumberOfDays
        ,
        [String]$SearchBase
    )

    Process {
        # На основании количества дней получаем крайнюю дату поиска устаревших аккаунтов.
        $DateWithOffset = (Get-Date).AddDays(-$NumberOfDays)

        # Формируем хэш-таблицу с параметрами для дальнейшей передачи их в командлет Get-ADComputer.
        $SearchParameters = @{
            Filter     = { LastLogonDate -lt $DateWithOffset }
            Properties = 'LastLogonDate'
        }

        if ($PSBoundParameters.ContainsKey('SearchBase')) {
            $SearchParameters.Add('SearchBase', $SearchBase)
        }

        # Получаем устаревшие аккаунты компьютеров в Active Directory.
        Get-ADComputer @SearchParameters
    }
}

function Move-ADComputerAccount {
    <#
    .SYNOPSIS
    Функция переноса аккаунта компьютера в другую организационную единицу.

    .DESCRIPTION
    Функция используется для переноса аккаунта компьютера в другую организационную единицу, когда не установлены командлеты для работы с Active Directory.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true)]
        [String[]]$ComputerName
        ,
        [Parameter(Mandatory = $true)]
        [String]$TargetOU
    )

    Process {
        foreach ($Computer in $ComputerName) {
            $ComputerDN = (([adsisearcher]"(&(ObjectCategory=Computer)(name=$Computer))").FindAll()).Properties.distinguishedname
            ([ADSI]"LDAP://$ComputerDN").psbase.MoveTo([ADSI]"LDAP://$TargetOU")
        }
    }
}