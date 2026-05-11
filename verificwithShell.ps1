# Verifica se o script está rodando como Administrador (Mantenha este bloco no topo)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando privilégios de administrador..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Rodando com permissões elevadas!" -ForegroundColor Green

# --- 1. CONFIGURAÇÃO DE FILTROS ---
# Filtro para Wi-Fi
$wifiFilter = { $_.Name -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*WLAN*" }

# Filtro para Ethernet
$ethFilter = { $_.Name -like "*Ethernet*" -or $_.InterfaceDescription -like "*Gigabit*" -or $_.InterfaceDescription -like "*PCIe FE*" }

# --- 2. EXECUÇÃO ---
Write-Host "`nIniciando verificação de adaptadores de rede..." -ForegroundColor Cyan
Write-Host "------------------------------------------------"

# Busca todos os adaptadores
$allAdapters = Get-NetAdapter

foreach ($adapter in $allAdapters) {
    $isWifi = $adapter | Where-Object $wifiFilter
    $isEth = $adapter | Where-Object $ethFilter
    
    # Se for Wi-Fi ou Ethernet, processamos
    if ($isWifi -or $isEth) {
        $tipo = if ($isWifi) { "Wi-Fi" } else { "Ethernet" }
        
        Write-Host "Encontrado: [$tipo] $($adapter.Name)" -NoNewline
        
        # Verifica se está desativado (Disabled)
        if ($adapter.Status -eq "Disabled") {
            Write-Host " -> [DESATIVADO]." -ForegroundColor Yellow
            
            # --- INTERAÇÃO COM O USUÁRIO ---
            $resposta = Read-Host "  Deseja ativar o adaptador $($adapter.Name) agora? (S/N)"
            
            # Verifica se a resposta começa com 'S' ou 's' (Sim/SIM/s/S)
            if ($resposta -match "^[Ss]") {
                Write-Host "  Ativando..." -ForegroundColor Cyan
                try {
                    Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                    Write-Host "  Sucesso: $($adapter.Name) foi ativado!" -ForegroundColor Green
                } catch {
                    Write-Host "  Erro: Não foi possível ativar." -ForegroundColor Red
                }
            } else {
                Write-Host "  Ação ignorada. O adaptador continuará desativado." -ForegroundColor DarkGray
            }
            # --------------------------------
            
        } else {
            Write-Host " -> [OK] (Status: $($adapter.Status))" -ForegroundColor Green
        }
    }
}

Write-Host "------------------------------------------------"
Write-Host "Verificação concluída.`n" -ForegroundColor Cyan
