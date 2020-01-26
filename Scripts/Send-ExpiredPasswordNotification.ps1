<#
.DESCRIPTION
Скрипт отправки почтового сообщения пользователям с истекающим сроком действия пароля.
Для исполнения в автоматическом режиме его необходимо поместить в назначенные задания и запускать утром, когда пользователи только приходят на работу.

.PARAMETER MailFrom
Параметр для указания почтового адреса, от которого ведётся рассылка.

.PARAMETER MailServer
Параметр для указания почтового сервера.

.PARAMETER MailAttach
Параметр для указания пути вложенного файла или файлов с инструкциями о смене пароля.

.PARAMETER TargetOU
Параметр для указания организационной единицы для поиска учётных записей с истекающим сроком действия пароля.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$MailFrom
    ,
    [Parameter(Mandatory = $true)]
    [String]$MailServer
    ,
    [String[]]$MailAttach
    ,
    [Parameter(Mandatory = $true)]
    [String]$TargetOU
)

# Объявляем переменные для отправки почтового сообщения.
$MailParameters = @{
    From       = $MailFrom
    Subject    = 'Истечение срока действия пароля'
    BodyAsHtml = $true
    Encoding   = [System.Text.Encoding]::UTF8
    SmtpServer = $MailServer
}

if ($PSBoundParameters.ContainsKey('MailAttach')) {
    $MailParameters.Add('Attachments', $MailAttach)
}

# Получаем пользователей, у которых срок действия пароля истекает в течение семи дней.
$Users = Get-ADUserAccountPasswordExpiringInfo -Filter { PasswordNeverExpires -eq $false } -SearchBase $TargetOU -Properties mail |
Where-Object { ($_.PasswordExpired -eq $false) -and ($_.DaysToExpire -lt '7') }

# Перебираем пользователей, формируем для них письмо об истечении срока действия пароля.
foreach ($User in $Users) {
    $MailParameters.To = $User.mail
    $Day = if ($User.DaysToExpire -eq '1') { 'день' } elseif ($User.DaysToExpire -le '4') { 'дня' } else { 'дней' }
    $MailMessage = '<html><body style="font-family:Calibri;font-syze:11">'
    $MailMessage += 'Уважаемый коллега!<br> Уведомляем, что пароль для Вашей учётной записи истекает через '
    $MailMessage += "$($User.DaysToExpire) $Day ($($User.ExpireDate.ToString([CultureInfo]::GetCultureInfo('ru-RU')))). "

    if ($PSBoundParameters.ContainsKey('MailAttach')) {
        $MailMessage += 'Для обновления пароля воспользуйтесь инструкцией во вложении.<br><br>'
    }

    $MailMessage += '<b>Это письмо создано автоматически, пожалуйста, не отвечайте на него.</b><br>'
    $MailMessage += '</body></html>'
    $MailParameters.Body = $MailMessage

    # Отправляем сформированное письмо.
    Send-MailMessage @MailParameters
}