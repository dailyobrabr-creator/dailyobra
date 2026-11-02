# Cria um arquivo de certificados usado só pelo Gradle do DailyObra: os certificados padrão do Java
# mais o "Avast Web/Mail Shield Root", que o Windows deste computador já aceita.
# Por quê: o Avast examina conexões HTTPS e troca o certificado dos sites; o Java do Gradle não confia
# nele e o build do Android não baixa as dependências (erro "PKIX path building failed").
# Não altera o Windows, o Avast nem o Java do Android Studio: só cria o arquivo abaixo.
# Uso (uma vez por computador): powershell -ExecutionPolicy Bypass -File tool\certificados_gradle.ps1

$ErrorActionPreference = 'Stop'
$jbr = 'C:\Program Files\Android\Android Studio\jbr'
$destino = Join-Path $env:USERPROFILE '.gradle\dailyobra-certificados.jks'

$cert = Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root |
  Where-Object { $_.Subject -like '*Avast Web/Mail Shield Root*' } |
  Select-Object -First 1
if (-not $cert) {
  Write-Output 'Certificado do Avast nao encontrado no Windows. Sem Avast, nao precisa deste arquivo.'
  exit 1
}

New-Item -ItemType Directory -Force (Split-Path $destino) | Out-Null
$cer = Join-Path $env:TEMP 'avast-web-shield.cer'
[IO.File]::WriteAllBytes($cer, $cert.Export('Cert'))
Copy-Item (Join-Path $jbr 'lib\security\cacerts') $destino -Force
& (Join-Path $jbr 'bin\keytool.exe') -importcert -noprompt -alias avast-web-shield -file $cer -keystore $destino -storepass changeit
Remove-Item $cer
Write-Output "Pronto: $destino"
