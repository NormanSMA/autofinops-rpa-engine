$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$facturas = Get-Content "$PSScriptRoot\facturas_extra.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$ret = "Retenci$([char]0xF3)n IR 2%"
foreach ($f in $facturas) {
  $l = @(
    "# FACTURA $($f.numero)", '',
    "**$($f.proveedor)**", '',
    "RUC: $($f.ruc)", '',
    "Factura No: $($f.numero)", '',
    "Fecha: $($f.fecha)", '',
    "Moneda: $($f.moneda)", '',
    'Cliente: Empresa Demo AutoFinOps S.A.', '',
    '| Concepto | Monto |', '|---|---|', "| $($f.concepto) | $($f.subtotal) |", '',
    "Subtotal: $($f.subtotal)  ", "IVA: $($f.iva)  ", "Total: $($f.total)  "
  )
  if ($f.retencion_ir) { $l += "${ret}: $($f.retencion_ir)  "; $l += "Neto a pagar: $($f.neto)" }
  $l += '', '---', '', 'Documento de prueba. Datos ficticios.'
  $md = Join-Path $env:TEMP "$($f.numero).md"
  [IO.File]::WriteAllText($md, ($l -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
  genoffice create --type pdf --from $md --out "$root\sample_invoices\$($f.archivo)" --force
  if ($LASTEXITCODE -ne 0) { throw "Fallo al generar $($f.archivo)" }
  Remove-Item $md
}
