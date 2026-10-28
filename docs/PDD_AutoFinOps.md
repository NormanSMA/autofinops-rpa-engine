# PDD AutoFinOps

## Objetivo y alcance

Automatiza la conciliación de facturas PDF mediante UiPath, PostgreSQL y el servicio cambiario BCN.
Procesa únicamente demostraciones con proveedores, RUC y documentos ficticios.
Describe el bot construido y las restricciones de `infra/init.sql`.

Incluye recepción, extracción, clasificación, conversión, validación, persistencia y auditoría.
Conserva reporte y notificación como RF-07 pendiente en los workflows revisados.
Excluye pagos, declaraciones fiscales, registros tributarios externos y modificación del esquema.
Usa PDF con texto para el recorrido básico.
Reconoce `Read PDF Text` y Regex como extracción existente sin OCR.
Interpreta IVA e IR como reglas demostrativas del proyecto.

## Entorno construido y configuración

Identifica la plantilla oficial como `UiPath.Template.REFramework` 26.10.1.
Usa Studio 26.10, lenguaje VisualBasic y compatibilidad Windows.
Conserva estas versiones declaradas para el entorno construido:

| Paquete | Versión |
| :--- | :--- |
| `UiPath.System.Activities` | 26.10.0 |
| `UiPath.PDF.Activities` | 4.3.0 |
| `UiPath.Database.Activities` | 2.1.1 |
| `UiPath.Mail.Activities` | 2.12.10 |
| `UiPath.WebAPI.Activities` | 2.5.2 |
| `UiPath.Excel.Activities` | 3.6.1 |

Lee `uipath_workflow/Data/Config.json` mediante las secciones `Settings` y `Constants`.
Consulta el inventario completo de claves reales en [la guía](guia-uipath-reframework.md#configuración-existente).

| Sección | Claves | Valores actuales |
| :--- | :--- | :--- |
| Settings | `OrchestratorQueueName`, `OrchestratorQueueFolder` | `Invoices_Queue`, `Shared`. |
| Settings | `InboxFolder`, `PendingFolder` | `Data\Input\Inbox`, `Data\Input\Pending`. |
| Settings | `ProcessedFolder`, `BusinessExceptionsFolder` | `Data\Output\Processed`, `Data\Output\Business_Exceptions`. |
| Settings | `PostgreSqlDsn`, `PGCredentialAssetName` | `AutoFinOps_PG`, `PG_Credential`. |
| Settings | `BcnServiceUrl`, `BcnTimeoutMs` | `https://servicios.bcn.gob.ni/Tc_Servicio/ServicioTC.asmx`, `30000`. |
| Settings | `MailEnabled`, `MailHost`, `MailPort`, `MailFolder` | `true`, `127.0.0.1`, `3143` (GreenMail), `INBOX`. |
| Settings | `MailCredentialAssetName`, `MailSubjectFilter` | `Mail_Credential`, `Factura\|Invoice\|Cobro`. |
| Constants | `MaxRetryNumber` | `0`. |
| Constants | `RetryNumberGetTransactionItem`, `RetryNumberSetTransactionStatus` | `2`, `2`. |
| Constants | `IvaRate`, `IrRate`, `IrThresholdNio`, `TaxTolerance` | `0.15`, `0.02`, `1000.00`, `0.05`. |

Reconoce psqlODBC 18.00.0005 como controlador instalado mediante `winget` en el entorno declarado.
Usa el DSN de usuario `AutoFinOps_PG` bajo la cuenta del robot.
Usa servidor `127.0.0.1`, puerto `5432` y base `autofinops_db`.
Mantén el DSN sin contraseña guardada.
Recupera `PG_Credential` mediante `Get Credential` dentro de `Process.xaml`.
Conecta mediante ODBC y la propiedad `ConnectionSecureString`.

## Recorrido implementado

Ejecuta `Dispatcher.xaml` como segundo entry point.
Usa IMAP cuando `MailEnabled=true`; usa `Data\Input\Inbox` cuando sea falso.
Filtra asuntos IMAP mediante `MailSubjectFilter` y guarda únicamente adjuntos PDF.
Considera `MarkAsRead=True` durante la recuperación y sobrescritura de adjuntos homónimos.
Mueve los PDF del buzón simulado a `Data\Input\Pending`.
Agrega un QueueItem por PDF pendiente a `Shared/Invoices_Queue`.
Usa el nombre sin extensión como `Reference`.
Guarda ruta absoluta y nombre mediante `SpecificContent("FilePath")` y `SpecificContent("FileName")`.
Configura referencia única, auto-retry y `Max retries = 2` en la cola.

Recupera cada QueueItem mediante `Framework/GetTransactionData.xaml`.
Ejecuta este recorrido dentro de `Framework/Process.xaml`:

1. Recupera `PG_Credential` y abre la conexión ODBC por intento.
2. Invoca `Extract_Invoice_PDF` para extraer campos escalares mediante `Read PDF Text` y Regex.
3. Invoca `Get_BCN_ExchangeRate` mediante `HTTP Request` POST SOAP para `RecuperaTC_Dia`.
4. Invoca `Validate_Tax_Rules` mediante dos `Run Query` parametrizados con `?`.
5. Aplica RF-05 mediante `Invoke Code` dentro de Validate.
6. Construye `in_Invoice` como `Dictionary(Of String, Object)` para `Insert_PostgreSQL`.
7. Ejecuta INSERT parametrizado de factura cuando corresponda y después INSERT de auditoría.
8. Mueve la factura a `Data\Output\Processed` o `Data\Output\Business_Exceptions`.
9. Lanza `BusinessRuleException` cuando el estado difiera de `CONCILIADA`.
10. Cierra la conexión mediante `Disconnect` dentro de `Finally`.

Conserva la respuesta informada de 36.6243 para la fecha de emisión 2026-10-20.
Distingue esa referencia de una consulta ejecutada durante esta revisión documental.

## As-Is vs To-Be

| Etapa | As-Is | To-Be |
| :--- | :--- | :--- |
| Recepción | Descarga manualmente los adjuntos. | Filtra correos pendientes y registra rutas en `Invoices_Queue`. |
| Extracción | Transcribe los datos del PDF. | Extrae texto y valida campos obligatorios. |
| Clasificación | Selecciona manualmente el centro de costo. | Consulta `providers`; devuelve `Sin clasificar` cuando falte proveedor. |
| Conversión | Consulta manualmente la tasa. | Consulta `RecuperaTC_Dia` usando la fecha de emisión. |
| Validación | Revisa cálculos y RUC manualmente. | Aplica catálogo, tolerancia, IVA e IR parametrizados. |
| Duplicidad | Busca coincidencias manualmente. | Aplica `uq_provider_invoice` sobre `provider_ruc` e `invoice_number`. |
| Evidencia | Conserva registros dispersos. | Registra resultados en `rpa_audit_logs` y organiza los PDF. |
| Reporte | Consolida hojas manualmente. | Conserva generación Excel y resumen HTML como RF-07 pendiente. |
| Rendimiento | Usa 4,5 minutos como referencia del blueprint. | Mide duración real; valida experimentalmente la meta de 5,2 segundos. |
| Calidad | Usa 4–7 % como referencia del blueprint. | Mide errores; evita presentar 0 % como resultado comprobado. |

## Requerimientos funcionales

| ID | Requerimiento | Criterio de aceptación |
| :--- | :--- | :--- |
| RF-01 | Recibe PDF mediante IMAP o buzón simulado. | Usa `MailEnabled`; conserva PDF en `Data\Input\Pending` y crea QueueItem por PDF. |
| RF-02 | Extrae proveedor, RUC, número, fecha, moneda, subtotal, IVA y total. | Devuelve argumentos escalares; lanza BRE-04 cuando falle la comprobación de campos. |
| RF-03 | Clasifica mediante proveedor activo. | Usa `providers.cost_center`; devuelve `Sin clasificar` cuando falte proveedor. |
| RF-04 | Consulta la tasa correspondiente a `issue_date`. | Convierte USD/NIO mediante una tasa positiva; evita sustituir errores por tasas ficticias. |
| RF-05 | Valida RUC, suma, IVA e IR. | Aplica `TaxTolerance`, `IvaRate`, `IrRate` e `IrThresholdNio`; respeta exención y estado `CONCILIADA`. |
| RF-06 | Persiste resultados y organiza PDF. | Respeta estados, tipos, obligatoriedad y unicidad de `infra/init.sql`. |
| RF-07 | Conserva reporte diario y notificación HTML como pendientes. | Implementa y prueba ambos antes de declarar este requerimiento cumplido. |

Usa estos centros de costo del catálogo activo:

- `Cloud & Infraestructura TI`.
- `Servicios Públicos & Telecom`.
- `Honorarios Legales & Admin`.
- `Suministros Operativos`.

Consulta `providers.provider_ruc` y exige `providers.active = TRUE`.
Trata proveedores inactivos como proveedores no autorizados mediante BRE-01.
Consulta `providers.is_tax_exempt` para decidir la exención.
Evita inferir exenciones desde el nombre del proveedor.
Conserva `Sin clasificar` cuando el RUC no exista en el catálogo activo.
Distingue el CHECK de categorías de `providers` de la columna contable sin ese CHECK.
No atribuyas clasificación por concepto a Validate.
Prioriza duplicidad BRE-03, proveedor BRE-01 y discrepancia fiscal BRE-02, en ese orden.

Calcula las reglas usando `Decimal`:

```text
Abs(subtotal_original + iva_amount_original - total_original) <= 0.05
iva_esperado = 0 cuando is_tax_exempt; en otro caso, Round(subtotal_original * 0.15, 2)
Abs(iva_amount_original - iva_esperado) <= 0.05
subtotal_nio = subtotal_original * exchange_rate_bcn cuando original_currency = USD
subtotal_nio = subtotal_original cuando original_currency = NIO
total_nio = total_original * exchange_rate_bcn cuando original_currency = USD
total_nio = total_original cuando original_currency = NIO
ir_retention_nio = 0
Si reconciliation_status = CONCILIADA y no is_tax_exempt y subtotal_nio > 1000.00:
    ir_retention_nio = Round(subtotal_nio * 0.02, 2)
net_payable_nio = Round(total_nio - ir_retention_nio, 2)
net_payable_usd = Round(net_payable_nio / exchange_rate_bcn, 2)
```

Aplica redondeo `MidpointRounding.AwayFromZero` en cálculos monetarios.
Conserva precisión intermedia; redondea los resultados monetarios a dos decimales.
No uses los campos netos observados como autorización de pago.
Para BRE-01 y BRE-02, registra `ir_retention_nio = 0` como política de revisión.
Conserva los totales declarados convertidos en los campos netos observados.
Conserva el motivo devuelto por Validate dentro de `validation_notes`.

## Requerimientos no funcionales

| ID | Requerimiento | Criterio de aceptación |
| :--- | :--- | :--- |
| RNF-01 | Separa errores de negocio y errores técnicos. | Lanza `BusinessRuleException` sin reintento; limita errores técnicos a dos reintentos. |
| RNF-02 | Mantén persistencia compatible con PostgreSQL 17. | Respeta el contrato de `infra/init.sql`; verifica infraestructura por separado. |
| RNF-03 | Protege credenciales y conexiones. | Usa Assets y `ConnectionSecureString`; excluye secretos de `Data/Config.json`. |
| RNF-04 | Audita cada intento con persistencia disponible. | Registra `queue_item_id`, `duration_ms`, `status`, `exception_type` y `error_message`; aplica best effort para SE. |
| RNF-05 | Conserva idempotencia contable. | Impide duplicados mediante `UNIQUE (provider_ruc, invoice_number)`; conserva la fila original. |

Conserva `MaxRetryNumber = 0` en `Constants`.
Para colas, configura dos reintentos en Orchestrator como único propietario del reintento transaccional.
Evita combinar reintentos automáticos con bucles internos sobre la misma factura.
Limita cada elemento a tres intentos totales.
Distingue `RetryNumberGetTransactionItem` de los reintentos transaccionales.
No atribuyas bucles de reintento IMAP ni notificación a los workflows existentes.

## Catálogo de excepciones

| Código | Clase | Condición | Acción | Reintento |
| :--- | :--- | :--- | :--- | :--- |
| BRE-01 | `BusinessRuleException` | RUC ausente del catálogo activo. | Marca `OBSERVADA_REGLA_NEGOCIO`; registra motivo; solicita revisión humana. | Ninguno. |
| BRE-02 | `BusinessRuleException` | IVA incorrecto o suma fuera de tolerancia. | Marca `OBSERVADA_REGLA_NEGOCIO`; conserva importes declarados; solicita revisión humana. | Ninguno. |
| BRE-03 | `BusinessRuleException` | Coincide `provider_ruc` e `invoice_number`. | Clasifica `RECHAZADA_DUPLICADA`; conserva factura original; audita el rechazo. | Ninguno. |
| BRE-04 | `BusinessRuleException` | El PDF no contiene los campos de una factura. | Lanza desde `Extract_Invoice_PDF`; audita sin factura; mueve a excepciones de negocio. | Ninguno. |
| SE-01 | `System.Exception` | BCN devuelve estado distinto de HTTP 200 o tasa no positiva. | Audita SE con conexión disponible; conserva PDF pendiente; propaga la excepción. | Hasta dos automáticos en la cola. |
| SE-00 | `System.Exception` | Ocurre un fallo técnico sin prefijo `SE-` dentro de Process. | Audita mediante best effort con conexión disponible; propaga la excepción. | Hasta dos automáticos en la cola. |

Comprueba BRE-04 cuando falten número, RUC, moneda, fecha o total según los patrones existentes.
Trata errores de conversión de fecha, subtotal o IVA como fallos técnicos propagados.
Trata errores de transporte y XML como técnicos; evita prometer siempre SE-01.
Conserva el prefijo `SE-` recibido; usa SE-00 cuando falte ese prefijo.
No atribuyas códigos propios SE-02 o SE-03 a errores sin esa conversión implementada.
Considera los errores IMAP fuera del procesamiento transaccional de Process.
Comprueba el aviso de Dispatcher cuando falle `Add Queue Item`.

Persiste observaciones solamente cuando todos los campos obligatorios estén disponibles.
Para BRE-01, conserva nombre extraído y centro de costo `Sin clasificar`.
Para BRE-04, registra solamente auditoría antes del movimiento a excepciones de negocio.
Condiciona esa auditoría y movimiento a la conexión disponible y persistencia completada.
Evita fabricar proveedor, categoría, fecha, moneda o tasa para completar una fila.

Trata BRE-03 como resultado del intento, sujeto a la restricción de unicidad.
No insertes una segunda fila ni actualices la factura previamente conciliada.
Registra el motivo BRE-03 devuelto por Validate en `error_message`.
El esquema admite ese estado; la unicidad impide una segunda fila equivalente.

## Mapeo estado → carpeta Data\Output

| Campo y valor | Carpeta final | Momento |
| :--- | :--- | :--- |
| `reconciliation_status = CONCILIADA` | `Data\Output\Processed` | Después de los comandos de factura y auditoría. |
| `reconciliation_status = OBSERVADA_REGLA_NEGOCIO` | `Data\Output\Business_Exceptions` | Después de registrar observación y auditoría. |
| `reconciliation_status = RECHAZADA_DUPLICADA` | `Data\Output\Business_Exceptions` | Después de auditar BRE-03; conserva la factura original. |
| BRE-04 con `status = BUSINESS_EXCEPTION` | `Data\Output\Business_Exceptions` | Después de completar auditoría sin factura. |
| `status = SYSTEM_EXCEPTION` | `Data\Input\Pending` | Conserva la ruta; no implementa movimiento técnico final. |

Durante reintentos técnicos, conserva el PDF en `Data\Input\Pending` cuando siga disponible.
No atribuyas un estado contable técnico a `invoices_reconciliation`.
Si PostgreSQL permanece caído, conserva evidencia en logs del robot y Orchestrator.
No atribuyas recuperación automática de auditoría al bot actual.
Considera otra fila SE si falla el movimiento después de registrar el resultado.

## Persistencia y auditoría

Mapea las columnas contables sin renombrarlas:

| Grupo | Columnas de `invoices_reconciliation` |
| :--- | :--- |
| Identidad | `reconciliation_id`, `invoice_number`, `provider_ruc`, `provider_name` |
| Clasificación | `cost_center`, `issue_date`, `original_currency` |
| Importes | `exchange_rate_bcn`, `subtotal_original`, `iva_amount_original`, `total_original` |
| Resultado | `ir_retention_nio`, `net_payable_nio`, `net_payable_usd`, `reconciliation_status`, `validation_notes` |
| Evidencia | `pdf_file_name`, `processed_by_bot`, `processed_at` |

Deja `reconciliation_id`, `processed_by_bot` y `processed_at` con sus valores predeterminados.
Inserta factura y auditoría mediante dos comandos parametrizados secuenciales.
Omite el INSERT contable cuando `in_WriteInvoice=False`.
No atribuyas una transacción atómica explícita ni rollback a `Insert_PostgreSQL`.
Detecta duplicidad previamente mediante la segunda consulta de Validate.
Conserva `uq_provider_invoice` como protección adicional ante duplicados concurrentes.
Trata una violación SQL posterior como técnica; no implementa conversión automática a BRE-03.

Usa estas columnas de `rpa_audit_logs`:

| Columna | Uso |
| :--- | :--- |
| `log_id` | Deja generar la clave automáticamente. |
| `queue_item_id` | Registra `Reference`; usa el nombre del PDF cuando falte referencia. |
| `invoice_number` | Registra el número conocido; permite `NULL` durante fallos de extracción. |
| `bot_stage` | Usa `End_Process`, `Tax_Validation` o la etapa donde falle el intento. |
| `status` | Usa exclusivamente `SUCCESS`, `BUSINESS_EXCEPTION` o `SYSTEM_EXCEPTION`. |
| `duration_ms` | Registra duración hasta iniciar persistencia final como entero no negativo. |
| `exception_type` | Usa `NULL` para éxito; usa `BRE` o `SE` para errores. |
| `error_code` | Registra BRE-01…BRE-04, SE-01 o SE-00 según el recorrido. |
| `error_message` | Registra resultado, motivo y contexto saneado; excluye secretos. |
| `logged_at` | Deja generar la fecha automáticamente. |

Comprueba `NULLIF` para número, tipo de excepción y código vacíos en la auditoría.
Observa `auditWritten` para evitar otra auditoría BRE del resultado ya registrado.
Audita SE mediante best effort solamente cuando exista conexión.
Registra el fallo de auditoría SE en logs y propaga el error técnico original.
No prometas una fila cuando PostgreSQL no permita persistencia.
Reserva `processed_at` y `logged_at` como filtros para RF-07 pendiente.
Interpreta `vw_finops_kpis` como vista global del esquema.

## Diferencias con el blueprint

- Unifica observaciones mediante `OBSERVADA_REGLA_NEGOCIO`; registra BRE-01 o BRE-02 en `validation_notes`.
- Conserva exclusivamente `CONCILIADA`, `OBSERVADA_REGLA_NEGOCIO` y `RECHAZADA_DUPLICADA` como estados contables.
- Alinea RNF-04 con `queue_item_id`, `duration_ms`, `status`, `exception_type` y `error_message`.
- Conserva `invoice_number`, `bot_stage` y `error_code` como contexto adicional de auditoría.
- Distingue estados contables de `SUCCESS`, `BUSINESS_EXCEPTION` y `SYSTEM_EXCEPTION`.
- Usa `Data/Config.json` como configuración con secciones `Settings` y `Constants`.
- Guarda credenciales UiPath mediante Assets; usa `ConnectionSecureString` para ODBC.
- Usa únicamente los cinco proveedores ficticios declarados en `infra/init.sql`.
- Conserva 36.6243 como respuesta informada para 2026-10-20; consulta BCN durante el procesamiento.
- Presenta tiempos y porcentajes del blueprint como referencias pendientes de medición.
- Conserva la factura original ante duplicidad; registra el rechazo en auditoría.

## Pruebas de aceptación

Consulta [las pruebas de la guía](guia-uipath-reframework.md#pruebas-con-uip-rpa-run).
Ejecuta `uip rpa run --help` desde la carpeta `uipath_workflow`.
Ejecuta `uip rpa run` con Dispatcher seleccionado mediante las opciones de tu CLI.
Ejecuta después `uip rpa run` con el entry point principal del Performer.

1. Procesa TeleRed con número nuevo para evitar duplicados existentes en los datos semilla.
2. Comprueba subtotal 4200, IVA 630, total 4830, IR 84 y neto NIO 4746.
3. Procesa Suministros con número nuevo; comprueba BRE-02 y `OBSERVADA_REGLA_NEGOCIO`.
4. Procesa un RUC ficticio ausente; comprueba BRE-01 y revisión humana.
5. Repite una factura; comprueba BRE-03 y una sola fila contable.
6. Procesa un PDF sin campos de factura; comprueba BRE-04 y auditoría sin factura.
7. Comprueba su movimiento a `Data\Output\Business_Exceptions` después de completar la auditoría.
8. Interrumpe BCN y PostgreSQL por separado; comprueba máximo tres intentos técnicos.
9. Distingue auditoría SE persistida de auditoría best effort fallida por conexión no disponible.
10. Prueba IMAP por separado; verifica errores sin atribuir códigos ni reintentos no implementados.
11. Comprueba `FilePath`, `FileName`, referencia única y carpeta `Shared` para cada elemento.
12. Conserva las pruebas de reporte y notificación pendientes hasta implementar RF-07.

Usa los PDF semilla originales para comprobar duplicidad contra registros existentes.
Prueba las reglas fiscales con copias ficticias numeradas nuevamente.
Comprueba NubeCentro sin IVA y sin IR: el proveedor tiene `is_tax_exempt = TRUE`.
Comprueba netos 6775.50 NIO y 185.00 USD, iguales al dato semilla.

## Límites de verificación

Distingue la inspección de archivos de una ejecución integrada mediante `uip rpa run`.
Verifica plantilla, versiones, driver instalado y configuración real de Orchestrator en el entorno operativo.
Conserva esos datos como información declarada fuera de los archivos permitidos para esta revisión.
No certifiques servicios, instalaciones ni RF-07 mediante esta revisión documental.
