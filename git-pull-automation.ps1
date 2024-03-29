#Requires -Version 5.0

<#
        .SYNOPSIS
            Скрипт проходит по вложенным папкам по переданному пути и выполняет команду git pull если выполнены условаия
            В папке есть вложенная папка .git И подключен удаленный репозиторий И доступен удаленный репозиторий (TCP22)
        .DESCRIPTION
            Дополнительное описание скрипта.

        .PARAMETER RootFolderPath
            Корневая папка, поиск осуществляется по вложеным папкам. В самой папке $RootFolderPath репозитории не ищются.

        .PARAMETER ConsoleStdout
            Параметр отвечает за вывод информации в консоль PwSH (silent (по-умолчанию) = вывод только результата, detailed = вывод всех сообщений )

        .EXAMPLE
            ./git-pull-automation.ps1 -RootFolderPath C:\Develop -ConsoleStdout silent
    #>

param(
    [Parameter(Mandatory = $true)]
    [string]$RootFolderPath,

    [ValidateSet("silent", "detailed")]
    [string]$ConsoleStdout = "detailed"
)

$global:Results = @()

# Функция для выполнения git pull в текущей папке
function PullGitRepository {
    param ()
    $currentPath = Get-Location
    # Проверка наличия папки .git
    $gitSubFolder = '.git'
    if (-not (Get-ChildItem $currentPath -Filter $gitSubFolder -Directory -Force)) {
        If ($ConsoleStdout -notlike 'silent') {
            Write-Host "Ошибка: Текущая папка $currentPath не является git репозиторием."      
        }
        return
    }

    #Проверка detached HEAD
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($currentBranch -eq "HEAD") {
        If ($ConsoleStdout -notlike 'silent') {
            Write-Host "Ошибка: Вы находитесь в 'detached HEAD' состоянии, git pull невозможен. $currentPath"
        }
        return
    }

    # Проверка подключенного репозитория
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) {
        If ($ConsoleStdout -notlike 'silent') {
            Write-Host "Ошибка: Удаленный репозиторий не найден. $currentPath"
        }
        return
    }

    # Проверка доступности удаленного репозитория с помощью команды ping
    $checkConnect = Test-Connection -ComputerName $(($remoteUrl -split ':')[0] -split '@')[1] -Count 1 -ErrorAction SilentlyContinue
    if ($checkConnect.StatusCode -eq 0) {
        If ($ConsoleStdout -notlike 'silent') {
            Write-Host "Выполняется git pull для репозитория $remoteUrl в ветке $currentBranch"
            $gitPullOutput = git pull
        }
        else { 
            $gitPullOutput = Invoke-Expression "git pull 2>&1"
        }

        # Результат выполнения git pull
        $pullStatus = if ($LASTEXITCODE -eq 0) {
            "Success: $gitPullOutput"
        }
        else {
            "Error: $($($($gitPullOutput.Exception.Message).Split(':')[2]).Trim())"
        }
    }
    else {
        If ($ConsoleStdout -notlike 'silent') { 
            Write-Host "Ошибка: Репозиторий '$remoteUrl' не доступен. $currentPath"
            }
        $pullStatus = "Error: Remote repo not available" 
         }
    
    #Добавляем в хеш-таблицу $Results новый объект $result
    $result = [PSCustomObject]@{
        Repository = (Get-Location).Path
        Branch     = $currentBranch
        Remote     = $remoteUrl
        Status     = $pullStatus
    }

    $global:Results += $result
}

# Функция для обхода всех подпапок и выполнения git pull в них
function ProcessSubfolders {
    [Parameter(Mandatory = $true)]
    param([string]$path)

    $subfolders = Get-ChildItem $path -Recurse -Depth 1 -Directory
    foreach ($subfolder in $subfolders) {
        Set-Location $subfolder.FullName
        PullGitRepository
        # Set-Location $RootFolderPath.FullName
    }
}

function BaseChecks {
    param ()
        # Проверка наличия корневой папки
    if (-not (Test-Path $RootFolderPath -PathType Container)) {
        Write-Host "Ошибка: Папка '$RootFolderPath' не найдена."
        exit
    }
    #Проверка установки git
    $gitRepo = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitRepo) {
        Write-Host "Ошибка: Git не найден. Убедитесь, что Git установлен и добавлен в переменную среды PATH."
        exit
    }
}


# Выполняем базовые проверки
BaseChecks
# Запускаем скрипт в указанной корневой папке
Set-Location $RootFolderPath
ProcessSubfolders $RootFolderPath
# Вывод результатов
$Results | Format-Table -AutoSize



