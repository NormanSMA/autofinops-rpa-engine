# Envia cada PDF de sample_invoices al buzon de prueba GreenMail (SMTP local, sin TLS).
# Uso: powershell -File scripts\enviar_facturas_correo.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root 'infra\.env'
$vars = @{}
Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Z_]+)=(.*)$' } | ForEach-Object { $vars[$Matches[1]] = $Matches[2] }
$domain = if ($vars['MAIL_DOMAIN']) { $vars['MAIL_DOMAIN'] } else { 'autofinops.test' }
$smtpPort = if ($vars['MAIL_SMTP_PORT']) { [int]$vars['MAIL_SMTP_PORT'] } else { 3025 }
$to = "$($vars['MAIL_USER'])@$domain"

$smtp = New-Object System.Net.Mail.SmtpClient('127.0.0.1', $smtpPort)
$smtp.EnableSsl = $false

$pdfs = Get-ChildItem (Join-Path $root 'sample_invoices') -Filter '*.pdf' | Sort-Object Name
foreach ($pdf in $pdfs) {
  $msg = New-Object System.Net.Mail.MailMessage("proveedores@demo.$domain", $to)
  $msg.Subject = "Factura $($pdf.BaseName)"
  $msg.Body = 'Adjunto la factura del periodo. Documento de prueba con datos ficticios.'
  $msg.Attachments.Add((New-Object System.Net.Mail.Attachment($pdf.FullName, 'application/pdf')))
  $smtp.Send($msg)
  $msg.Dispose()
}

$noise = New-Object System.Net.Mail.MailMessage("boletin@demo.$domain", $to)
$noise.Subject = 'Boletin mensual de noticias'
$noise.Body = 'Este correo no trae factura; el Dispatcher debe ignorarlo.'
$smtp.Send($noise)
$noise.Dispose()

Write-Output "Enviados $($pdfs.Count) correos con factura y 1 correo sin factura a $to"
