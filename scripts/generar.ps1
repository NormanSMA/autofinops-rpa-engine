$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pdfs = @{
  'factura_nubecentro'   = 'INV_NubeCentro_2026_10.pdf'
  'factura_telered'      = 'Factura_TeleRed_Oct2026.pdf'
  'factura_suministros'  = 'Factura_Suministros_ErrorIVA.pdf'
}
foreach ($k in $pdfs.Keys) {
  genoffice create --type pdf --from "$PSScriptRoot\$k.md" --out "$root\sample_invoices\$($pdfs[$k])" --force
  if ($LASTEXITCODE -ne 0) { throw "Fallo al generar $($pdfs[$k])" }
}
