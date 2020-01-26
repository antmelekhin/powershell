function Get-Translit {
    <#
    .DESCRIPTION
    Функция транслитерации текста из кириллицы на латиницу. Исходный скрипт взят из статьи https://habr.com/ru/post/242445/ и дополнен.

    .LINK
    Регламент транслитерации взят из Приказа от 29 марта 2016 г. №4271 МИД РФ (Приложение №7):
    http://www.consultant.ru/cons/cgi/online.cgi?req=doc&base=LAW&n=214752&fld=134&dst=1000000001,0&rnd=0.8582624208021307#0
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [String]$InString
    )

    Begin {
        #Создаём хеш-таблицу соответствия символов.
        $Translit = @{
            [Char]'а' = 'a'
            [Char]'А' = 'A'
            [Char]'б' = 'b'
            [Char]'Б' = 'B'
            [Char]'в' = 'v'
            [Char]'В' = 'V'
            [Char]'г' = 'g'
            [Char]'Г' = 'G'
            [Char]'д' = 'd'
            [Char]'Д' = 'D'
            [Char]'е' = 'e'
            [Char]'Е' = 'E'
            [Char]'ё' = 'e'
            [Char]'Ё' = 'E'
            [Char]'ж' = 'zh'
            [Char]'Ж' = 'Zh'
            [Char]'з' = 'z'
            [Char]'З' = 'Z'
            [Char]'и' = 'i'
            [Char]'И' = 'I'
            [Char]'й' = 'i'
            [Char]'Й' = 'I'
            [Char]'к' = 'k'
            [Char]'К' = 'K'
            [Char]'л' = 'l'
            [Char]'Л' = 'L'
            [Char]'м' = 'm'
            [Char]'М' = 'M'
            [Char]'н' = 'n'
            [Char]'Н' = 'N'
            [Char]'о' = 'o'
            [Char]'О' = 'O'
            [Char]'п' = 'p'
            [Char]'П' = 'P'
            [Char]'р' = 'r'
            [Char]'Р' = 'R'
            [Char]'с' = 's'
            [Char]'С' = 'S'
            [Char]'т' = 't'
            [Char]'Т' = 'T'
            [Char]'у' = 'u'
            [Char]'У' = 'U'
            [Char]'ф' = 'f'
            [Char]'Ф' = 'F'
            [Char]'х' = 'kh'
            [Char]'Х' = 'Kh'
            [Char]'ц' = 'ts'
            [Char]'Ц' = 'Ts'
            [Char]'ч' = 'ch'
            [Char]'Ч' = 'Ch'
            [Char]'ш' = 'sh'
            [Char]'Ш' = 'Sh'
            [Char]'щ' = 'shch'
            [Char]'Щ' = 'Shch'
            [Char]'ъ' = 'ie'
            [Char]'Ъ' = 'Ie'
            [Char]'ы' = 'y'
            [Char]'Ы' = 'Y'
            [Char]'ь' = ''
            [Char]'Ь' = ''
            [Char]'э' = 'e'
            [Char]'Э' = 'E'
            [Char]'ю' = 'iu'
            [Char]'Ю' = 'Iu'
            [Char]'я' = 'ia'
            [Char]'Я' = 'Ia'
        }
        $TranslitResult = ''
    }

    Process {
        # Перебираем посимвольно строку, находим соответствие и добавляем его к результату.
        foreach ($Char in $InString.ToCharArray()) {
            if ($null -cne $Translit[$Char]) { $TranslitResult += $Translit[$Char] }
            else { $TranslitResult += $Char }
        }
    }

    End {
        # Выводим результат на экран.
        $TranslitResult
    }
}