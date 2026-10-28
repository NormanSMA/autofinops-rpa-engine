# Pruebas de aceptación — AutoFinOps-NI

Ejecución real del 2026-10-28 contra Orchestrator Cloud (carpeta `Shared`), PostgreSQL 17.11 en Docker y el servicio web del BCN.
Datos ficticios de demostración.

## Entorno

| Elemento | Valor |
|---|---|
| Studio | UiPath Studio 26.10, plantilla `UiPath.Template.REFramework` 26.10.1 |
| Ejecución | `uip rpa run` (UiPath CLI 1.204.0, robot conectado a Orchestrator) |
| Cola | `Invoices_Queue` · reintentos 2 · referencia única |
| Credencial | Asset `PG_Credential` (Credential) en `Shared` |
| Base | PostgreSQL 17.11 · DSN ODBC `AutoFinOps_PG` · psqlODBC 18.00.0005 |
| Tasa BCN | `RecuperaTC_Dia` devolvió 36.6243 para todas las fechas de octubre 2026 |

## Cómo reproducir

```powershell
docker compose -f infra/docker-compose.yml up -d
Copy-Item sample_invoices\*.pdf uipath_workflow\Data\Input\Inbox\
cd uipath_workflow
uip rpa run --file-path Dispatcher.xaml --project-dir .
uip rpa run --file-path Main.xaml --project-dir .
```

## Resultado por factura (18 PDFs)

| Caso | Facturas | Estado esperado | Estado obtenido | Carpeta final |
|---|---|---|---|---|
| NIO con IVA 15% e IR 2% | FAC-2026-1101 a 1105 | CONCILIADA | CONCILIADA | Processed |
| NIO bajo umbral, sin IR | FAC-2026-1106, 1107 | CONCILIADA | CONCILIADA | Processed |
| USD exenta | FAC-2026-1108 a 1110 | CONCILIADA | CONCILIADA | Processed |
| USD con IVA e IR | FAC-2026-1111, 1112 | CONCILIADA | CONCILIADA | Processed |
| IVA erróneo (BRE-02) | FAC-2026-1113, 1114 | OBSERVADA_REGLA_NEGOCIO | OBSERVADA_REGLA_NEGOCIO | Business_Exceptions |
| RUC no registrado (BRE-01) | FAC-2026-1115 | OBSERVADA_REGLA_NEGOCIO | OBSERVADA_REGLA_NEGOCIO | Business_Exceptions |
| Duplicada del seed (BRE-03) | FAC-2026-0891, 4410, 9902 | RECHAZADA_DUPLICADA | RECHAZADA_DUPLICADA | Business_Exceptions |

Cola tras la corrida: 12 `Successful`, 6 `Failed` (Business Exception). Sin excepciones de sistema.

## Cálculos verificados en base de datos

| Factura | Moneda | Subtotal | IVA | IR (NIO) | Neto NIO | Neto USD |
|---|---|---|---|---|---|---|
| FAC-2026-1101 | NIO | 3,850.00 | 577.50 | 77.00 | 4,350.50 | 118.79 |
| FAC-2026-1108 | USD | 120.00 | 0.00 | 0.00 | 4,394.92 | 120.00 |
| FAC-2026-1111 | USD | 500.00 | 75.00 | 366.24 | 20,692.73 | 565.00 |
| FAC-2026-1113 | NIO | 3,000.00 | 240.00 | 0.00 | 3,240.00 | 88.47 |

Regla: IR 2% solo si el proveedor no es exento y el subtotal en NIO supera C$ 1,000.00. Redondeo a 2 decimales, mitad hacia arriba.

## KPIs (`vw_finops_kpis`) tras la corrida

| KPI | Valor |
|---|---|
| total_facturas_procesadas | 19 (4 del seed + 15 nuevas; 3 duplicadas rechazadas) |
| facturas_conciliadas_ok | 15 |
| facturas_con_alerta | 4 |
| porcentaje_exito_conciliacion | 78.95 |
| total_aprobado_cordobas | 125,518.46 |
| total_aprobado_dolares | 3,427.21 |
| total_retencion_ir_nio | 1,633.44 |

## Auditoría (`rpa_audit_logs`, RNF-04)

| status | exception_type | error_code | Filas | Promedio ms |
|---|---|---|---|---|
| SUCCESS | — | — | 15 | 1,687 |
| BUSINESS_EXCEPTION | BRE | BRE-01 | 1 | 472 |
| BUSINESS_EXCEPTION | BRE | BRE-02 | 3 | 1,386 |
| BUSINESS_EXCEPTION | BRE | BRE-03 | 3 | 411 |

Incluye las 4 filas del seed.

## Excepción de sistema (RNF-01)

Prueba: se detuvo el contenedor `autofinops_postgres` y se encoló una factura (`SE_TEST_DB_DOWN`).

| Intento | Resultado |
|---|---|
| 1 | `ERROR [08001] connection refused` → System Exception |
| 2 | Reintento automático de la cola → System Exception |
| 3 | Reintento automático de la cola → System Exception |

Estado final del elemento: `Failed` tras 2 reintentos. El PDF quedó en `Input/Pending` para reproceso. La auditoría SE no se escribe cuando la base está caída: el bot registra un aviso y continúa.

## Ingesta por correo IMAP (RF-01)

Buzón de prueba GreenMail 2.1.15 en Docker (`autofinops_mail`, IMAP 3143, SMTP 3025). Credencial en el Asset `Mail_Credential`.

```powershell
powershell -File scripts\enviar_facturas_correo.ps1
cd uipath_workflow
uip rpa run --file-path Dispatcher.xaml --project-dir .
uip rpa run --file-path Main.xaml --project-dir .
```

| Paso | Resultado |
|---|---|
| Correos enviados | 18 con factura PDF + 1 boletín sin factura |
| Dispatcher (`MailEnabled=true`) | 18 elementos encolados; el boletín se ignoró por el filtro de asunto |
| Performer | 12 CONCILIADA · 2 BRE-02 · 1 BRE-01 · 3 BRE-03 · 0 SE |
| `vw_finops_kpis` | 19 facturas · 78.95 % de éxito · C$ 125,518.46 aprobado |
| Carpetas | 12 en Processed · 6 en Business_Exceptions · 0 en Pending |

El resultado coincide con la corrida por buzón simulado.

## No cubierto

- Correo real (Gmail o Microsoft 365); solo se probó el buzón GreenMail.
- RF-07: reporte Excel y correo HTML.
- Caída del servicio BCN (SE-01); el código está, la prueba no se ejecutó.
- BRE-04 (PDF sin campos de factura).
