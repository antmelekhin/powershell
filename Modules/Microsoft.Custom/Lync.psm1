function Get-LyncCmdlets {
    <#
    .SYNOPSIS
    Функция загрузки командлетов Lync (Skype for Business) в локальную сессию администратора.

    .EXAMPLE
    Загружает все командлеты с сервера lynk.domain.local в локальную сессию администратора.
    Get-LyncCmdlets -ServerName lynk.domain.local

    .EXAMPLE
    Загружает командлеты Get-CsUser и Set-CsUser с сервера lynk.domain.local в локальную сессию администратора.
    Get-LyncCmdlets -ServerName lynk.domain.local -LyncCmdlets Get-CsUser, Set-CsUser

    .NOTES
    Для подключения к Lync (Skype for Business) необходимо настроить WinRM over HTTPS.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$ServerName
        ,
        [String[]]$LyncCmdlets
    )

    Process {
        # Подключаемся к серверу Lync (Skype for Business).
        $LyncOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        $LyncSession = New-PSSession -ConnectionUri "https://$ServerName/OcsPowershell" -Authentication NegotiateWithImplicitCredential -SessionOption $LyncOptions

        # Формируем хэш-таблицу с параметрами для дальнейшей передачи их в командлет Import-PSSession.
        $SessionParameters = @{
            Session      = $LyncSession
            AllowClobber = $true
        }

        if ($PSBoundParameters.ContainsKey('LyncCmdlets')) {
            $SessionParameters.Add('CommandName', $LyncCmdlets)
        }

        # Загружаем командлеты в локальную сессию администратора.
        $null = Import-Module (Import-PSSession @SessionParameters) -Global
    }
}