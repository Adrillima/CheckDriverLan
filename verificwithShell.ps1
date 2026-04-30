# --- 1. CONFIGURAÇÃO DE FILTROS ---
# Filtro para Wi-Fi
$wifiFilter = { $_.Name -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*WLAN*" }

# Filtro para Ethernet
$ethFilter = { $_.Name -like "*Ethernet*" -or $_.InterfaceDescription -like "*Gigabit*" -or $_.InterfaceDescription -like "*PCIe FE*" }

# --- 2. EXECUÇÃO ---
Write-Host "Iniciando verificação de adaptadores de rede..." -ForegroundColor Cyan
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
            Write-Host " -> [DESATIVADO]. Ativando agora..." -ForegroundColor Yellow
            try {
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                Write-Host "Sucesso: $($adapter.Name) foi ativado!" -ForegroundColor Green
            } catch {
                Write-Host "Erro: Não foi possível ativar. Você está rodando como Administrador?" -ForegroundColor Red
            }
        } else {
            Write-Host " -> [OK] (Status: $($adapter.Status))" -ForegroundColor Green
        }
    }
}

Write-Host "------------------------------------------------"
Write-Host "Verificação concluída." -ForegroundColor Cyan