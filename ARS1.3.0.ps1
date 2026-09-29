# Verifica se o script está rodando como Administrador (Obrigatório para gerenciar hardware)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando privilégios de administrador..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- CONFIGURAÇÃO DA JANELA DO CONSOLE ---
$hostUI = $Host.UI.RawUI
$novaLargura = 90
$novaAltura = 25

# Tenta ajustar o tamanho da janela e o buffer (área de rolagem)
try {
    $tamanhoJanela = $hostUI.WindowSize
    $tamanhoJanela.Width = $novaLargura
    $tamanhoJanela.Height = $novaAltura
    
    $tamanhoBuffer = $hostUI.BufferSize
    $tamanhoBuffer.Width = $novaLargura
    # Mantém o buffer de altura grande para não perder o histórico de texto se rolar para cima
    $tamanhoBuffer.Height = 300 

    # Aplica as configurações (o Buffer deve ser ajustado primeiro se a janela for ficar maior, ou depois se for ficar menor. O try/catch lida com isso)
    $hostUI.BufferSize = $tamanhoBuffer
    $hostUI.WindowSize = $tamanhoJanela
} catch {
    # Ignora silenciosamente se o terminal do usuário não suportar redimensionamento (ex: novo Windows Terminal em algumas configurações)
}
# -----------------------------------------

Write-Host "Rodando com permissões elevadas!" -ForegroundColor Green

# --- 1. CONFIGURAÇÃO DO FILTRO ESPECÍFICO ---
# Lista de drivers alvo. Você pode adicionar quantos quiser separando por vírgula e aspas.
# Lista de drivers alvo (Cobre ~95% dos PCs Windows atuais)
# Lista de drivers alvo (Cobre ~95% dos PCs Windows atuais)

$targetDrivers = @(
    # --- REALTEK (Extremamente comum na maioria das placas-mãe) ---
    "Realtek PCIe GbE Family Controller",      # Rede a cabo Gigabit padrão
    "Realtek PCIe FE Family Controller",       # Rede a cabo mais antiga (100Mbps)
    "Realtek PCIe 2.5GbE Family Controller",   # Rede a cabo rápida (PCs gamers/novos)
    "Realtek USB GbE Family Controller",       # Rede a cabo via adaptadores USB/Hubs
    "Realtek RTL8",                            # Pega a maioria dos Wi-Fi Realtek (ex: RTL8822CE, RTL8188)

    # --- INTEL (Dominante em notebooks e PCs corporativos/Premium) ---
    "Intel(R) 82579V Gigabit Network Connection", # O seu específico
    "Intel(R) Ethernet Connection",               # Pega as séries I219-V, I219-LM (Muito comum)
    "Intel(R) Ethernet Controller",               # Pega as séries I225-V, I226-V
    "Intel(R) Dual Band Wireless-AC",             # Pega os Wi-Fi Intel antigos (ex: 3165, 8265, 9260)
    "Intel(R) Wi-Fi 6",                           # Pega os Wi-Fi modernos (AX200, AX201)
    "Intel(R) Wi-Fi 6E",                          # Pega os Wi-Fi super novos (AX210, AX211)

    # --- MEDIATEK (Muito comum em notebooks modernos com processador AMD Ryzen) ---
    "MediaTek Wi-Fi 6",                        # Pega as placas MT7921 (Muito comum na Asus, Lenovo)
    "MediaTek Wi-Fi 6E",                       # Pega as placas MT7922

    # --- QUALCOMM ATHEROS (Comum em notebooks de entrada e antigos) ---
    "Qualcomm Atheros QCA",                    # Pega a série QCA9377 e similares
    "Qualcomm Atheros AR",                     # Pega a série AR956x, AR9000, etc.

    # --- KILLER (Comum em notebooks Gamers: Dell G, Alienware, Acer Predator) ---
    "Killer E",                                # Pega Ethernet (E2500, E2600, E3100)
    "Killer Wi-Fi 6"                           # Pega Wi-Fi Killer (AX1650, AX1675)
)

Write-Host "`nIniciando verificação focada na lista de drivers específicos..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------"

# Busca todos os adaptadores de rede e filtra apenas os que estão na nossa lista
$targetAdapters = Get-NetAdapter | Where-Object {
    $adapter = $_
    $encontrou = $false
    foreach ($driver in $targetDrivers) {
        # Usamos -like para evitar problemas com os parênteses (R) no nome da Intel
        if ($adapter.InterfaceDescription -like "*$driver*" -or $adapter.Name -like "*$driver*") {
            $encontrou = $true
            break
        }
    }
    $encontrou
}

# Se nenhum adaptador da lista for encontrado, avisar o usuário
if (-not $targetAdapters) {
    Write-Host "Erro: Nenhum dos adaptadores da lista foi localizado no sistema." -ForegroundColor Red
    Write-Host "-------------------------------------------------------------"
    Write-Host "Verificação concluída.`n" -ForegroundColor Cyan
    # Read-Host "Pressione Enter para sair."
    exit
}

# --- 2. EXECUÇÃO DA VERIFICAÇÃO ---
# Inicia um loop caso encontre mais de um adaptador da lista na mesma máquina
foreach ($targetAdapter in $targetAdapters) {
    
    Write-Host "Processando: $($targetAdapter.Name) ($($targetAdapter.InterfaceDescription))" -ForegroundColor Magenta

    # --- VERIFICAÇÃO NO GERENCIADOR DE DISPOSITIVOS (HARDWARE) ---
    $pnpDevice = Get-PnpDevice -InstanceId $targetAdapter.PnpDeviceID -ErrorAction SilentlyContinue

    # O código 0 significa que o dispositivo está funcionando corretamente
    if ($pnpDevice -and $pnpDevice.ConfigManagerErrorCode -ne 0) {
        Write-Host " -> [ERRO DE HARDWARE/DRIVER] (Código: $($pnpDevice.ConfigManagerErrorCode))" -ForegroundColor Red
        
        $respRefresh = Read-Host "  O driver travou. Deseja dar um refresh (reiniciar o driver no nível do hardware) agora? (S/N)"
        
        if ($respRefresh -match "^[Ss]") {
            Write-Host "  Reiniciando o driver físico no nível PnP (isso pode levar alguns segundos)..." -ForegroundColor Cyan
            try {
                # Desabilita o dispositivo no nível do Gerenciador de Dispositivos PnP
                Disable-PnpDevice -InstanceId $targetAdapter.PnpDeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 3 # Aguarda 3 segundos para o hardware "desligar" completamente
                
                # Habilita novamente
                Enable-PnpDevice -InstanceId $targetAdapter.PnpDeviceID -Confirm:$false -ErrorAction Stop
                Write-Host "  Sucesso: Refresh do hardware concluído! O driver físico foi reiniciado." -ForegroundColor Green
            } catch {
                Write-Host "  Erro: Falha ao tentar reiniciar o driver no nível PnP." -ForegroundColor Red
            }
        } else {
            Write-Host "  Ação ignorada. O driver físico continuará com erro." -ForegroundColor DarkGray
        }

    # --- VERIFICAÇÃO DE STATUS DE REDE (SOFTWARE) ---
    # Se o hardware estiver OK, mas a conexão de rede estiver desativada.
    } elseif ($targetAdapter.Status -eq "Disabled") {
        Write-Host " -> [DESATIVADO NO NÍVEL DE REDE]." -ForegroundColor Yellow
        
        $resposta = Read-Host "  Deseja ativar o adaptador $($targetAdapter.Name) agora? (S/N)"
        
        if ($resposta -match "^[Ss]") {
            Write-Host "  Ativando conexão de rede..." -ForegroundColor Cyan
            try {
                Enable-NetAdapter -Name $targetAdapter.Name -Confirm:$false
                Write-Host "  Sucesso: A conexão de rede de $($targetAdapter.Name) foi ativada!" -ForegroundColor Green
            } catch {
                Write-Host "  Erro: Não foi possível ativar a conexão de rede." -ForegroundColor Red
            }
        } else {
            Write-Host "  Ação ignorada. O adaptador continuará desativado na rede." -ForegroundColor DarkGray
        }
        
    } else {
        Write-Host " -> [OK] (Status de Rede: $($targetAdapter.Status), Hardware: Funcionando)" -ForegroundColor Green
    }
    
    Write-Host "-------------------------------------------------------------"
}

Write-Host "Verificação de todos os adaptadores da lista concluída.`n" -ForegroundColor Cyan
# Read-Host "Pressione Enter para sair."