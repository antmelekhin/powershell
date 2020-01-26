function New-ADUserAccount {
    <#
    .SYNOPSIS
    Функция создания учётных записей в Active Directory, Skype for Business и почтового ящика Exchange.

    .DESCRIPTION
    Функция используется для автоматического создания учётных записей из файла выгруженного в программе кадрового учёта. Функцию также удобно использовать напрямую из терминала.

    .PARAMETER SamAccountName
    Параметр для указания имени входа в систему и формирования UserPrincipalName, соответствует атрибуту sAMAccountName.

    .PARAMETER LastName
    Параметр для указания фамилии, соответствует атрибуту sn. Используется для формирования имени объекта в Active Directory и отображаемого имени (displayName).

    .PARAMETER FirstName
    Параметр для указания имени, соответствует атрибуту givenName. Используется для формирования имени объекта в Active Directory и отображаемого имени (displayName).

    .PARAMETER MiddleName
    Параметр для указания отчества, соответствует атрибуту middleName. Может использоваться для формирования имени объекта в Active Directory и отображаемого имени (displayName).

    .PARAMETER DefaultPassword
    Параметр для указания пароля учётной записи по умолчанию, который мы передаём пользователю. Необходимо сменить при первом входе в систему. Если не указан, то учётная запись создаётся выключенной и без пароля.

    .PARAMETER ADAttributes
    Параметр для указания дополнительный атрибутов учётной записи пользователя Active Directory. Соответствует параметру OtherAttributes командлета New-ADUser.

    .PARAMETER DomainController
    Параметр для указания контроллера домена, на котором создаётся учётная запись Active Directory. Если не указан, то используется контроллер для компьютера, на котором исполняется скрипт.

    .PARAMETER TargetOU
    Параметр для указания организационной единицы, в которой будет создана учётная запись пользователя. Если не указан, то учётная запись создаётся в контейнере Users.

    .PARAMETER ExchDB
    Параметр для указания базы данных Exchange, в которой будет храниться почтовый ящик пользователя. Соответствует параметру Database командлета Enable-Mailbox.

    .PARAMETER ExchArchiveDB
    Параметр для указания базы данных Exchange, в которой будет храниться архив, связанный с почтовым ящиком пользователя. Соответствует параметру ArchiveDatabase командлета Enable-Mailbox.

    .PARAMETER ExchRetentionPolicy
    Параметр для указания имени политики хранения, которая будет применяться к почтовому ящику пользователя. Соответствует параметру RetentionPolicy командлета Enable-Mailbox.

    .PARAMETER LyncRegistrar
    Параметр для указания регистрационного пула Lync, в котором будет располагаться учётная запись пользователя. Соответствует параметру RegistrarPool командлета Enable-CsUser.

    .EXAMPLE
    New-ADUserAccount -SamAccountName ivanov -LastName Иванов -FirstName Иван -MiddleName Иванович -ADAttributes @{ 'department' = 'Отдел продаж' } -ExchDB Main_DB -LyncRegistrar lynk.domain.local
    Создаём учётную запись пользователя из командной строки.

    .EXAMPLE
    Get-Content .\new-user.json | ConvertFrom-Json | ForEach-Object {
        $AttrInHash = @{ }
        $_.OtherAttributes.PSObject.Properties | ForEach-Object { $AttrInHash.Add($_.Name, $_.Value) }
        New-ADUserAccount -SamAccountName $_.SamAccountName -LastName $_.LastName -FirstName $_.FirstName -MiddleName $_.MiddleName -ADAttributes $AttrInHash -TargetOU 'OU=Users,OU=Company,DC=Domain,DC=Local' -ExchDB Main_DB -LyncRegistrar lynk.domain.local
    }
    Создаём учётную запись пользователя из json файла.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$SamAccountName
        ,
        [Parameter(Mandatory = $true)]
        [String]$LastName
        ,
        [Parameter(Mandatory = $true)]
        [String]$FirstName
        ,
        [String]$MiddleName
        ,
        [SecureString]$DefaultPassword
        ,
        [Hashtable]$ADAttributes
        ,
        [String]$DomainController
        ,
        [String]$TargetOU
        ,
        [Parameter(Mandatory = $true)]
        [String]$ExchDB
        ,
        [String]$ExchArchiveDB
        ,
        [String]$ExchRetentionPolicy
        ,
        [Parameter(Mandatory = $true)]
        [String]$LyncRegistrar
    )

    # Назначаем переменные параметров для создания учётной записи пользователя.
    if ($PSBoundParameters.ContainsKey('MiddleName')) {
        $FullName = "$LastName $FirstName $MiddleName"
    }
    else { $FullName = "$LastName $FirstName" }

    if (-not $PSBoundParameters.ContainsKey('DomainController')) {
        $DomainController = (Get-ADDomainController).HostName
    }

    $UserPrincipalName = $SamAccountName + '@' + (Get-ADDomain -Server $DomainController).DNSRoot

    # Формируем хэш-таблицу с параметрами для дальнейшей передачи их в командлет New-ADUser.
    $ADParameters = @{
        'DisplayName'       = $FullName
        'GivenName'         = $FirstName
        'SamAccountName'    = $SamAccountName
        'Server'            = $DomainController
        'Surname'           = $LastName
        'UserPrincipalName' = $UserPrincipalName
    }

    if ($PSBoundParameters.ContainsKey('ADAttributes')) {
        $ADParameters.Add('OtherAttributes', $ADAttributes)
    }

    if ($PSBoundParameters.ContainsKey('MiddleName')) {
        $ADParameters.Add('OtherName', $MiddleName)
    }

    if ($PSBoundParameters.ContainsKey('TargetOU')) {
        $ADParameters.Add('Path', $TargetOU)
    }

    if ($PSBoundParameters.ContainsKey('DefaultPassword')) {
        $ADParameters.Add('AccountPassword', $DefaultPassword)
        $ADParameters.Add('ChangePasswordAtLogon', $true)
        $ADParameters.Add('Enabled', $true)
    }

    # Создаём учётную запись пользователя в Active Directory.
    New-ADUser $FullName @ADParameters

    # Включаем почтовый ящик пользователя в Exchange.
    $null = Enable-Mailbox $SamAccountName -Database $ExchDB -DomainController $DomainController

    # Включаем архивирование почтового ящика в Exchange.
    if ($PSBoundParameters.ContainsKey('ExchArchiveDB')) {
        $null = Enable-Mailbox $SamAccountName -Archive -ArchiveDatabase $ExchArchiveDB -DomainController $DomainController

        # Указываем политику хранения писем в почтовом ящике.
        if ($PSBoundParameters.ContainsKey('ExchRetentionPolicy')) {
            Set-Mailbox $SamAccountName -RetentionPolicy $ExchRetentionPolicy -DomainController $DomainController
        }
    }

    # Включаем учётную запись пользователя в Lync.
    Enable-CsUser $SamAccountName -DomainController $DomainController -RegistrarPool $LyncRegistrar -SipAddressType 'EmailAddress'
}

function Set-ADUserAccount {
    <#
    .SYNOPSIS
    Функция изменения атрибутов учётных записей в Active Directory.

    .DESCRIPTION
    Функция используется для автоматического изменения атрибутов учётных записей из файла выгруженного в программе кадрового учёта.
    Можно использовать из командной строки, но для более гибкой работы с изменением учётных записей лучше использовать командлет Set-ADUser.

    .PARAMETER Identity
    Параметр для указания учётной записи пользователя Active Directory. Соответствует параметру Identity командлета Set-ADUser.

    .PARAMETER ADAttributes
    Параметр для указания изменяемых атрибутов учётной записи пользователя Active Directory.

    СИНТАКСИС:
    Для изменения атрибутов нужно указывать ключ с новым значением. Для очистки атрибута нужно указать ключ, а значении должно быть $null.

    -ADAttributes @{ 'employeeID' = '000001' }
    Меняем значение атрибута 'employeeID'.

    -ADAttributes @{ 'extensionAttribute1' = $null }
    Очищаем атрибут 'extensionAttribute1'

    .EXAMPLE
    Get-ADUser -LDAPFilter '(name=Иванов Иван Иванович)' | Set-ADUserAccount -ADAttributes @{ 'department' = 'Отдел кадров'; 'description' = $null }
    Ищем пользователя с ФИО "Иванов Иван Иванович" и меняем в его учётной записи атрибут 'department' и очищаем атрибут 'description'.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]$Identity
        ,
        [Parameter(Mandatory = $true)]
        [Hashtable]$ADAttributes
    )

    Begin {
        # Создаём и наполняем хэш-таблицу с параметрами для замены.
        $ReplaceAttributes = @{ }
        $PSBoundParameters.ADAttributes.GetEnumerator() |
        Where-Object { $null -ne $_.Value } | ForEach-Object { $ReplaceAttributes.Add($_.Name, $_.Value) }

        # Создаём и наполняем массив с параметрами для очистки.
        $ClearAttributes = @()
        $PSBoundParameters.ADAttributes.GetEnumerator() |
        Where-Object { $null -eq $_.Value } | ForEach-Object { $ClearAttributes += $_.Name }

        # Собираем хэш-таблицу с параметрами для передачи их в командлет Set-ADUser.
        $ADParameters = @{ }
        if ($ReplaceAttributes.Count -ne '0') { $ADParameters.Add('Replace', $ReplaceAttributes) }
        if ($ClearAttributes) { $ADParameters.Add('Clear', $ClearAttributes) }
    }

    Process {
        # Обновляем атрибуты существующей учётной записи.
        foreach ($User in $Identity) { Set-ADUser $User @ADParameters }
    }
}

function Disable-ADUserAccount {
    <#
    .SYNOPSIS
    Функция отключения учётных записей в Active Directory, Skype for Business и почтового ящика Exchange.

    .DESCRIPTION
    Функция используется в сценариях поиска недействительных или учётных записей с истёкшим сроком действия.

    .PARAMETER Identity
    Параметр для указания учётной записи пользователя Active Directory. Соответствует параметру Identity командлета Get-ADUser.

    .PARAMETER ClearADAttributes
    Параметр для очистки атрибутов учётной записи Active Directory. Соответствует параметру Clear командлета Set-ADUser.

    .PARAMETER TargetOU
    Параметр для указания организационной единицы, в которую будет перемещена учётная запись пользователя. Если не указан, то учётная запись остаётся в своей организационной единице.

    .PARAMETER DomainController
    Параметр для указания контроллера домена, на котором отключается учётная запись Active Directory. Если не указан, то используется контроллер для компьютера, на котором исполняется скрипт.

    .EXAMPLE
    Search-ADAccount -AccountExpired -SearchBase 'OU=Users,OU=Company,DC=Domain,DC=Local' | Disable-ADUserAccount -ClearADAttributes manager, physicalDeliveryOfficeName -TargetOU 'OU=Disabled_Users,OU=Company,DC=Domain,DC=Local'
    Ищем объекты пользователей с истёкшим сроком действия учётной записи, очищаем атрибуты 'manager' и 'physicalDeliveryOfficeName', отключаем и переносим в организационную единицу для отключенных.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]$Identity
        ,
        [String[]]$ClearADAttributes
        ,
        [String]$TargetOU
        ,
        [String]$DomainController
    )

    Begin {
        if (-not $PSBoundParameters.ContainsKey('DomainController')) {
            $DomainController = (Get-ADDomainController).HostName
        }
    }

    Process {
        foreach ($UserForDisable in (Get-ADUser $Identity -Properties *)) {
            # Отлючаем учётную запись пользователя в Lync.
            Disable-CsUser $UserForDisable.SamAccountName -DomainController $DomainController

            # Отключаем почтовый ящик пользователя на мобильном устройстве и удаляем его контакт из адресной книги Outlook.
            Set-CASMailbox $UserForDisable.SamAccountName -ActiveSyncEnabled $false -DomainController $DomainController -OWAEnabled $false
            Set-Mailbox $UserForDisable.SamAccountName -DomainController $DomainController -HiddenFromAddressListsEnabled $true

            # Очищаем атрибуты учётной записи пользователя Active Directory.
            if ($PSBoundParameters.ContainsKey('ClearADAttributes')) {
                Set-ADUser $UserForDisable -Clear $ClearADAttributes
            }

            # Исключаем учётную запись пользователя Active Directory из всех групп кроме основной.
            $DomainSID = (Get-ADDomain).DomainSID.Value
            $PrimaryGroupID = $UserForDisable.primaryGroupID
            $Groups = Get-ADPrincipalGroupMembership $UserForDisable | Where-Object { $_.SID -ne "$($DomainSID + '-' + $PrimaryGroupID)" }

            if ($Groups) {
                Remove-ADPrincipalGroupMembership $UserForDisable -MemberOf $Groups -Confirm:$false
            }

            # Отлючаем учётную запись пользователя в Active Directory.
            Disable-ADAccount $UserForDisable -Server $DomainController

            # Перемещаем учётную запись пользователя Active Directory в организационную единицу для отключенных.
            if ($PSBoundParameters.ContainsKey('TargetOU')) {
                Move-ADObject $UserForDisable -TargetPath $TargetOU -Server $DomainController
            }
        }
    }
}

function Get-ADUserAccountPasswordExpiringInfo {
    <#
    .SYNOPSIS
    Функция вывода информации о сроке действия пароля учётной записи Active Directory.

    .DESCRIPTION
    Функция используется для вывода информации о сроке действия пароля учётной записи Active Directory. Может использоваться как отдельно, так и в сценариях уведомления пользователей об истечении срока действия пароля.

    .PARAMETER Identity
    Параметр для указания учётной записи пользователя Active Directory. Соответствует параметру Identity командлета Get-ADUser.

    .PARAMETER Filter
    Параметр строки запроса к Active Directory для извлечения учётных записей пользователя. Соответствует параметру Filter командлета Get-ADUser.

    .PARAMETER Properties
    Параметр получения свойств объекта учётной записи пользователя. По умолчанию получает свойства PasswordExpired, PasswordLastSet и PasswordNeverExpires. Можно указывать дополнительные, например mail в сценарии уведомления пользователя.
    Соответствует параметру Properties командлета Get-ADUser.

    .PARAMETER SearchBase
    Параметр для указания организационной единицы Active Directory, в которой ведётся поиск. Соответствует параметру SearchBase командлета Get-ADUser.

    .EXAMPLE
    Get-ADUserAccountPasswordExpiringInfo ivanov -Properties mail
    UserName             : Иванов Иван Иванович
    SamAccountName       : ivanov
    PasswordExpired      : False
    PasswordLastSet      : 11.03.2019 10:52:18
    ExpireDate           : 11.06.2019 10:52:18
    DaysToExpire         : 25
    PasswordNeverExpires : False
    Enabled              : True
    mail                 : ivanov@domain.ru

    Выводит информацию о сроке действия пароля учётной записи ivanov.

    .EXAMPLE
    Get-ADUserAccountPasswordExpiringInfo -Filter * -SearchBase 'OU=Users,OU=Company,DC=Domain,DC=Local'
    Выводит информацию о сроке действия пароля учётных записей находящихся в указанной организационной единице.
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'Filter'
    )]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0,
            ParameterSetName = 'User'
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]$Identity
        ,
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Filter'
        )]
        [String]$Filter
        ,
        [Parameter(ParameterSetName = 'User')]
        [Parameter(ParameterSetName = 'Filter')]
        [String[]]$Properties
        ,
        [Parameter(ParameterSetName = 'Filter')]
        [String]$SearchBase
    )

    Begin {
        # Назначаем переменные параметров для вычисления даты и количества дней до истечения срока действия пароля.
        $CurrentDate = Get-Date
        $MaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

        # И для формирования вывода свойств объекта.
        $DefaultProperties = 'PasswordExpired', 'PasswordLastSet', 'PasswordNeverExpires'
        if ($PSBoundParameters.ContainsKey('Properties')) {
            $NonDefaultProperties = $PSBoundParameters.Properties
            $PSBoundParameters.Properties += $DefaultProperties
        }
        else { $PSBoundParameters.Add('Properties', $DefaultProperties) }
    }

    Process {
        # Создаём массив для наполнения его всеми объектами для дальнейшего вывода на экран.
        [System.Collections.ArrayList]$UserResults = @()

        # Перебираем указанные учётные записи, создаём и наполняем объект свойствами.
        foreach ($User in (Get-ADUser @PSBoundParameters)) {

            # Расчитываем дату и количество дней до истечения срока действия пароля только для пользователей, которые его уже меняли.
            if ($null -ne $User.PasswordLastSet) {
                $ExpireDate = $User.PasswordLastSet + $MaxPasswordAge
                $DaysToExpire = ($ExpireDate - $CurrentDate).Days
            }

            # Создаём и наполняем объект свойствами.
            $UserObject = [PSCustomObject]@{
                Name                 = $User.Name
                SamAccountName       = $User.SamAccountName
                PasswordExpired      = $User.PasswordExpired
                PasswordLastSet      = $User.PasswordLastSet
                ExpireDate           = $ExpireDate
                DaysToExpire         = $DaysToExpire
                PasswordNeverExpires = $User.PasswordNeverExpires
                Enabled              = $User.Enabled
            }

            # Если пользователь указал дополнительные свойства для вывода, то добавляем их в объект.
            if ($NonDefaultProperties) {
                $NonDefaultProperties | ForEach-Object {
                    $UserObject | Add-Member -MemberType NoteProperty -Name $_ -Value $User.$_
                }
            }

            # Сохраняем все объекты в массив для вывода на экран.
            $null = $UserResults.Add($UserObject)
        }
    }

    End {
        # Вывод результатов на экран.
        $UserResults
    }
}