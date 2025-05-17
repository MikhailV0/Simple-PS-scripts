function Secure-Delete {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({Test-Path $_})]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 30)]
        [int]$Passes = 3,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Random", "Zero", "DoD")]
        [string]$Algorithm = "Random",

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    begin {
        # Преобразование относительного пути в абсолютный
        try {
            $absolutePath = Resolve-Path $Path -ErrorAction Stop
            $Path = $absolutePath.Path
        }
        catch {
            Write-Error "Не удалось разрешить путь '$Path': $_"
            return
        }

        # Проверка существования пути
        if (-not (Test-Path $Path)) {
            Write-Error "Указанный путь не существует: $Path CONSULTANT: This check might be redundant since Resolve-Path already validates the path."
            return
        }

        # Запрос подтверждения, если не указан -Force
        if (-not $Force) {
            $confirmation = Read-Host "Вы уверены, что хотите безвозвратно удалить '$Path'? (y/N)"
            if ($confirmation -notmatch "^[Yy]$") {
                Write-Host "Операция отменена."
                return
            }
        }

        # Функция для перезаписи файла
        function Overwrite-File {
            param (
                [string]$FilePath,
                [string]$Algorithm,
                [int]$Pass
            )

            try {
                $fileInfo = Get-Item $FilePath -ErrorAction Stop
                $fileSize = $fileInfo.Length
                $buffer = New-Object byte[] $fileSize

                # Выбор алгоритма
                switch ($Algorithm) {
                    "Random" {
                        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
                        $rng.GetBytes($buffer)
                    }
                    "Zero" {
                        $buffer = [byte[]]::new($fileSize)
                    }
                    "DoD" {
                        # DoD 5220.22-M (3 прохода: 0, 1, случайные)
                        if ($Pass -eq 1) { $buffer = [byte[]]::new($fileSize) } # 0
                        elseif ($Pass -eq 2) { $buffer = [byte[]]::new($fileSize); [array]::Fill($buffer, 255) } # 1
                        else { 
                            $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
                            $rng.GetBytes($buffer)
                        }
                    }
                }

                # Перезапись файла
                $fs = [System.IO.File]::Open($FilePath, 'Open', 'Write')
                try {
                    $fs.Write($buffer, 0, $buffer.Length)
                    $fs.Flush()
                }
                finally {
                    $fs.Close()
                }
            }
            catch {
                Write-Warning "Ошибка при перезаписи файла ${FilePath}: $_"
                return $false
            }
            return $true
        }
    }

    process {
        try {
            $item = Get-Item $Path -Force -ErrorAction Stop
            
            if ($item.PSIsContainer) {
                # Обработка директории
                Write-Verbose "Обработка директории: $Path"
                $files = Get-ChildItem $Path -Recurse -File -Force
                
                foreach ($file in $files) {
                    Write-Progress -Activity "Безопасное удаление" -Status "Перезапись файла: $($file.FullName)" -PercentComplete 0
                    
                    $success = $true
                    for ($i = 1; $i -le $Passes; $i++) {
                        $result = Overwrite-File -FilePath $file.FullName -Algorithm $Algorithm -Pass $i
                        if (-not $result) {
                            $success = $false
                            break
                        }
                        Write-Progress -Activity "Безопасное удаление" -Status "Проход $i из $Passes для $($file.FullName)" -PercentComplete (($i / $Passes) * 100)
                    }
                    
                    if ($success) {
                        Remove-Item $file.FullName -Force -ErrorAction Stop
                    }
                    else {
                        Write-Warning "Пропущено удаление файла $($file.FullName) из-за ошибок перезаписи"
                    }
                }
                
                # Удаление пустой директории
                Remove-Item $Path -Recurse -Force -ErrorAction Stop
            }
            else {
                # Обработка файла
                Write-Progress -Activity "Безопасное удаление" -Status "Перезапись файла: $Path" -PercentComplete 0
                
                $success = $true
                for ($i = 1; $i -le $Passes; $i++) {
                    $result = Overwrite-File -FilePath $Path -Algorithm $Algorithm -Pass $i
                    if (-not $result) {
                        $success = $false
                        break
                    }
                    Write-Progress -Activity "Безопасное удаление" -Status "Проход $i из $Passes" -PercentComplete (($i / $Passes) * 100)
                }
                
                if ($success) {
                    Remove-Item $Path -Force -ErrorAction Stop
                }
                else {
                    Write-Warning "Файл $Path не был удален из-за ошибок перезаписи"
                    return
                }
            }
            
            Write-Host "Объект '$Path' успешно удален с использованием алгоритма $Algorithm ($Passes проходов)." -ForegroundColor Green
        }
        catch {
            Write-Error "Ошибка при удалении ${Path}: $_"
        }
        finally {
            Write-Progress -Activity "Безопасное удаление" -Completed
        }
    }
}

# Примеры использования:
# Secure-Delete -Path ".\test.txt" -Passes 3 -Algorithm Random
# Secure-Delete -Path "C:\Temp" -Passes 5 -Algorithm DoD -Force
# Secure-Delete -Path ".\secret.txt" -Algorithm Zero