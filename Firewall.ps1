#On/Off all firewall profiles in Windows
#Mikhail Volokhov
#24.12.2022

function DisplayMainMenu {
    Clear-Host
    Write-Host @"
+===============================================+
|            ENABLE/DISABLE FIREWALL            | 
+===============================================+
|                                               |
|    1) Enable firewall                         |
|    2) Disable firewall                        |
|    3  Get Firewall Status                     |
|    4) Exit                                    |
+===============================================+

"@
    $MENU = Read-Host "Select a menu item"
    Switch ($MENU) {
        1 {
            #Enable firewall
            Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
            Get-NetFirewallProfile | Format-Table Name, Enabled
            Read-Host "Press Enter ..."
            Break
        }
        2 {
            #Disable firewall
            Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
            Get-NetFirewallProfile | Format-Table Name, Enabled
            Read-Host "Press Enter ..."
            Break
        }
        3 {
            #Status
            Get-NetFirewallProfile | Format-Table Name, Enabled
            Read-Host "Press Enter ..."
            DisplayMainMenu
        }
        4{
            Break
        }
        default {
            #DEFAULT OPTION
            Write-Host "A non-existent menu item is selected"
            Start-Sleep -Seconds 1
            DisplayMainMenu
        }
    }
}

DisplayMainMenu
