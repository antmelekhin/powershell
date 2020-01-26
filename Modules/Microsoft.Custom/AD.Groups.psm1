function Copy-ADGroupsFromTemplate {
    <#
    .SYNOPSIS
    Функция копирования групп безопасности.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$SourceUser
        ,
        [Parameter(Mandatory = $true)]
        [String]$DestinationUser
        ,
        [Switch]$RemoveDestinationUserCurrentGroups
    )

    Process {
        # Назначаем переменную SID домена. Она понадобится для определения основной группы у целевой учётной записи и учётной записи источника копирования.
        $DomainSID = (Get-ADDomain).DomainSID.Value

        # Удаляем текущие группы, кроме основной, у целевой учётной записи, если это указано.
        if ($PSBoundParameters.ContainsKey('RemoveDestinationUserCurrentGroups')) {
            $DestinationUserPrimaryGroupID = (Get-ADUser $DestinationUser -Properties primaryGroupID).primaryGroupID
            $RemovedGroups = Get-ADPrincipalGroupMembership $DestinationUser | Where-Object { $_.SID -ne "$($DomainSID + '-' + $DestinationUserPrimaryGroupID)" }
            Remove-ADPrincipalGroupMembership $DestinationUser -MemberOf $RemovedGroups -Confirm:$false
        }

        # Копирование текущих групп, кроме основной, от учётной записи источника.
        $SourceUserPrimaryGroupID = (Get-ADUser $SourceUser -Properties primaryGroupID).primaryGroupID
        $CopiedGroups = Get-ADPrincipalGroupMembership $SourceUser | Where-Object { $_.SID -ne "$($DomainSID + '-' + $SourceUserPrimaryGroupID)" }
        Add-ADPrincipalGroupMembership $DestinationUser -MemberOf $CopiedGroups
    }
}