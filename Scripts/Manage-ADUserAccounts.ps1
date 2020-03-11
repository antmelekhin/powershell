<#
.SYNOPSIS
Скрипт обсуживания учётных записей Active Directory.

.DESCRIPTION
Скрипт используется для создания, изменения и выставления срока действия учётных записей в Active Directory. Для использования необходимо добавить путь откуда будут читаться json файлы и установить все необходимые переменные, также можно добавить скриптблоки, например для добавления в группы или авторизации в других сервисах компании.

Скрипт читает json файл следующего вида:
{
    "LastName": "Петров",
    "FirstName": "Пётр",
    "MiddleName": "Петрович",
    "OtherAttributes": {
        "l": "Москва",
        "Company": "ООО \"Компания\"",
        "Division": "Отдел продаж",
        "Department": null,
        "Title": "Старший специалист",
        "Manager": "Иванов Иван Иванович",
    },
    "Date": "10.01.2019",
    "Action": "New"
}

LastName, FirstName и MiddleName - ФИО.
OtherAttributes - любой атрибут учётной записи, но нужно помнить, что ключ - это существующий или же специально созданый атрибут Active Directory. Ключи в нём могут быть в том числе и пустыми.
Ключ Date, в данном скрипте, необходим только для выставления даты последнего рабочего дня увольняющихся сотрудников.
Action - действие, которое выполняется над учётной записью, в скрипте их определено три: New для создания новой учётной записи, Set для изменения текущей и Disable для выставления срока действия.
Для исполнения в автоматическом режиме его необходимо поместить в назначенные задания и запускать по времени от пользователя, у которого есть права на изменение атрибутов учётных записей.
#>

# Переменная для указания пути, по которому находятся создаваемые json файлы.
$JsonPath = '\\shared\folder\*.json'

# Если в каталоге присутствуют файлы, то исполняем код ниже, если файлы отсутствуют - ничего не делаем.
if (Test-Path -Path $JsonPath) {
    # Подключаем необходимые командлеты.
    Get-ExchCmdlets -ServerName 'exch-01' -ExchCmdlets Get-MailboxDatabase, Enable-Mailbox, Set-Mailbox
    Get-LyncCmdlets -ServerName 'lynk.domain.local' -LyncCmdlets Enable-CsUser

    foreach ($JsonFile in (Get-ChildItem -Path $JsonPath).FullName) {
        # Конвертируем json файл в PSObject.
        $UserObject = Get-Content -Path $JsonFile | ConvertFrom-Json

        # Назначаем начальные переменнные.
        $LastName = $UserObject.LastName
        $FirstName = $UserObject.FirstName
        $MiddleName = $UserObject.MiddleName
        $SamAccountName = Get-Translit ($FirstName[0] + $MiddleName[0] + $LastName).ToLower()

        # Ищем пользователя в Active Directory.
        $ADUser = Get-ADUser -LDAPFilter "(name=$LastName $FirstName $MiddleName)"

        # Т.к. командлеты принимают параметры в хэш-таблице - создаём её из PSObject.
        if ($UserObject.OtherAttributes.PSObject) {
            $AttrInHash = @{ }
            $UserObject.OtherAttributes.PSObject.Properties | ForEach-Object { $AttrInHash.Add($_.Name, $_.Value) }

            # Из json файла должны передаваться значения в формате атрибутов Active Directory.
            # Например: из программы кадрового учёта значение поля "Руководитель" передаётся в формате "ФИО", а значение
            # атрибута Active Directory, в который мы его записываем, должно быть в формате различающегося имени.
            if ($AttrInHash.Manager) {
                $ManagerObject = Get-ADUser -LDAPFilter "(name=$($AttrInHash.Manager))" -Properties mail
                $AttrInHash.Manager = $ManagerObject.DistinguishedName
            }
        }

        switch ($UserObject.Action) {
            # Приём на работу.
            New {
                if (-not $ADUser) {
                    # Назначаем переменные необходимые для создания нового пользователя.
                    $DomainController = 'dc-01'
                    $Password = 'Qwerty123'
                    $MailDomain = 'domain.ru'
                    $TargetOU = 'OU=Users,OU=Company,DC=Domain,DC=Local'
                    $ExchArchiveServer = 'exch-02'
                    $ExchRetentionPolicy = '2 Months'
                    $LyncServer = 'lynk.domain.local'

                    # Назначаем переменную для выбора базы данных, в которой будет храниться основной почтовый ящик нового пользователя при условии, что для каждого города она своя.
                    switch ($UserObject.OtherAttributes.l) {
                        Москва { $ExchDB = 'MSK_DB' }
                        Санкт-Петербург { $ExchDB = 'SPB_DB' }
                        Default { $ExchDB = 'REGIONS_DB' }
                    }

                    # Назначаем переменную для выбора базы данных, в которой будет храниться архивный почтовый ящик нового пользователя. Если на серевере несколько баз данных, то будет выбрана с меньшим размером.
                    $ExchArchiveDB = (Get-ExchDatabase -Server $ExchArchiveServer | Sort-Object DatabaseSize).DatabaseName[0]

                    # Удаляем ключи с пустыми значениями из хэш-таблицы, т.к. командлет их не принимает.
                    ($AttrInHash.GetEnumerator() | Where-Object { $null -eq $_.Value }) | ForEach-Object { $AttrInHash.Remove($_.Name) }

                    $NewUserParameters = @{
                        'SamAccountName'      = $SamAccountName
                        'LastName'            = $LastName
                        'FirstName'           = $FirstName
                        'MiddleName'          = $MiddleName
                        'DefaultPassword'     = (ConvertTo-SecureString $Password -AsPlainText -Force)
                        'ADAttributes'        = $AttrInHash
                        'DomainController'    = $DomainController
                        'TargetOU'            = $TargetOU
                        'ExchDB'              = $ExchDB
                        'ExchArchiveDB'       = $ExchArchiveDB
                        'ExchRetentionPolicy' = $ExchRetentionPolicy
                        'LyncRegistrar'       = $LyncServer
                    }

                    # Назначаем переменную основных параметров для отправки уведомительного письма.
                    $MailParameters = @{
                        'SmtpServer' = 'mail.domail.ru'
                        'Encoding'   = 'UTF8'
                        'BodyAsHtml' = $true
                    }

                    # Назначаем переменную для отправки уведомительного письма о подключении нового сотрудника.
                    # Если письмо отправляется не от того же пользователя от которого исполняется скрипт, то необходимо убедиться, что в Exchange настроено делегирование.
                    $NotificationMail = @{
                        'From'    = 'support@domain.ru'
                        'Subject' = 'Подключение нового сотрудника к информационным ресурсам'
                    }

                    # Добавляем адресатов уведомительного письма.
                    if ($ManagerObject.mail) { $NotificationMail.To = $ManagerObject.mail, 'it_notification@domain.ru' }
                    else { $NotificationMail.To = 'it_notification@domain.ru' }

                    # Добавляем тело уведомительного письма.
                    $NotificationMail.Body = ("<html><body style=`"font-family:Calibri;font-syze:11`">" +
                        "Сотрудник $LastName $FirstName $MiddleName подключен к внутренним ресурсам компании. " +
                        "Дата выхода сотрудника: $($UserObject.Date)." +
                        "</html></body>")

                    # Назначаем переменную для отправки приветственного письма новому пользователю.
                    $WelcomeMail = @{
                        'From'    = 'hr@domain.ru'
                        'To'      = $SamAccountName + '@' + $MailDomain
                        'Subject' = 'Добро пожаловать!'
                    }

                    # Добавляем тело приветственного письма для нового сотрудника.
                    $WelcomeMail.Body = ("<html><body style=`"font-family:Calibri;font-syze:11`">" +
                        "Уважаемый коллега! Приветствуем в Нашей компании!<br><br>" +
                        "</html></body>")

                    # Создаём пользователя и отправляем уведомительные письма.
                    New-ADUserAccount @NewUserParameters
                    Send-MailMessage @MailParameters @NotificationMail
                    Send-MailMessage @MailParameters @WelcomeMail
                }
            }

            # Кадровое перемещение
            Set {
                try {
                    Set-ADUserAccount -Identity $ADUser.SamAccountName -ADAttributes $AttrInHash -ErrorAction Stop
                }
                catch {
                    $Exception = $_.Exception.Message
                    Write-Host ('При изменении пользователя {0} {1} {2} возникла ошибка: {3}' -f $LastName, $FirstName, $MiddleName, $Exception)
                }
            }

            # Увольнение
            Disable {
                # Данные по сотруднику могут быть выгружены раньше на две недели, поэтому для таких учётных записей выставляется срок действия, который соответствует фактической дате увольнения.
                # Если по пятницам короткий рабочий день, например до 16:45, то время отключения учётной записи выставляем соответствующее, в остальные дни - 18:00.
                if ((Get-Date $UserObject.Date).DayOfWeek -eq 'Friday') { $Time = '16:45:00' }
                else { $Time = '18:00:00' }

                $TimeSpan = ([DateTime]::Parse("$($UserObject.Date) $Time") - (Get-Date)).ToString()
                Set-ADAccountExpiration -Identity $ADUser.SamAccountName -TimeSpan $TimeSpan
            }
        }

        # Удаляем прочитанный json файл.
        Remove-Item -Path $JsonFile
    }
}