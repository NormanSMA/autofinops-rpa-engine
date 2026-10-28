# Guía UiPath Studio 26.10: AutoFinOps

## Preparación

Usa los workflows existentes del bot para ejecutar las pruebas.
Identifica la plantilla oficial como `UiPath.Template.REFramework` 26.10.1.
Usa Studio 26.10, lenguaje VisualBasic y compatibilidad Windows.
Distingue el Performer de `Dispatcher.xaml`, segundo entry point del proyecto.
Consulta `infra/init.sql` como contrato de persistencia.

### Paquetes del entorno declarado

| Paquete | Versión | Uso existente |
| :--- | :--- | :--- |
| `UiPath.System.Activities` | 26.10.0 | Controla archivos, cola, argumentos y excepciones. |
| `UiPath.PDF.Activities` | 4.3.0 | Extrae texto mediante `Read PDF Text`. |
| `UiPath.Database.Activities` | 2.1.1 | Conecta mediante ODBC y ejecuta SQL parametrizado. |
| `UiPath.Mail.Activities` | 2.12.10 | Recibe correos IMAP y envía reportes SMTP con adjunto. |
| `UiPath.WebAPI.Activities` | 2.5.2 | Envía SOAP mediante `HTTP Request` POST. |
| `UiPath.Excel.Activities` | 3.6.1 | Genera el reporte mediante `Write Range Workbook`, sin Excel instalado. |

Conserva las versiones indicadas por el entorno construido.
Identifica RF-07 implementado mediante `Workflows/Send_Daily_Report.xaml`.

### Driver psqlODBC y DSN AutoFinOps_PG

Reconoce psqlODBC 18.00.0005 como controlador instalado mediante `winget` en el entorno declarado.
Comprueba el DSN de usuario `AutoFinOps_PG` bajo la cuenta del robot.
Usa servidor `127.0.0.1`, puerto `5432` y base `autofinops_db`.
Mantén el DSN sin contraseña guardada.
Comprueba permisos sobre `providers`, `invoices_reconciliation`, `rpa_audit_logs` y sus secuencias.

### Assets y conexión

Usa el Asset Credential `PG_Credential` para PostgreSQL.
Localiza `Get Credential` dentro de `Framework/Process.xaml`.
Observa la conexión por intento mediante `Connect` y proveedor `System.Data.Odbc`.
Identifica `ConnectionSecureString` como propiedad utilizada por la actividad.
Mantén las credenciales fuera de configuración, documentación y logs.
Observa `Disconnect` dentro de `Finally` para cada intento.
Usa `Mail_Credential` para recepción IMAP cuando `MailEnabled=true`.
Usa también `Mail_Credential` para RF-07, independientemente de `MailEnabled`.

## Configuración existente

Lee `uipath_workflow/Data/Config.json` mediante las secciones `Settings` y `Constants`.
Observa la invocación de `InitAllSettings` desde Dispatcher con ambas secciones.
Usa las siguientes claves reales del archivo.

| Sección | Clave | Valor actual | Uso |
| :--- | :--- | :--- | :--- |
| Settings | `logF_BusinessProcessName` | `AutoFinOps` | Identifica el proceso. |
| Settings | `OrchestratorQueueName` | `Invoices_Queue` | Selecciona la cola. |
| Settings | `OrchestratorQueueFolder` | `Shared` | Selecciona la carpeta de cola. |
| Settings | `InboxFolder` | `Data\Input\Inbox` | Define el buzón simulado. |
| Settings | `PendingFolder` | `Data\Input\Pending` | Conserva los PDF pendientes. |
| Settings | `ProcessedFolder` | `Data\Output\Processed` | Conserva las facturas conciliadas. |
| Settings | `BusinessExceptionsFolder` | `Data\Output\Business_Exceptions` | Conserva los rechazos de negocio. |
| Settings | `PostgreSqlDsn` | `AutoFinOps_PG` | Selecciona el DSN de usuario. |
| Settings | `PGCredentialAssetName` | `PG_Credential` | Selecciona el Asset PostgreSQL. |
| Settings | `BcnServiceUrl` | `https://servicios.bcn.gob.ni/Tc_Servicio/ServicioTC.asmx` | Define el endpoint SOAP. |
| Settings | `BcnTimeoutMs` | `30000` | Limita la solicitud HTTP en milisegundos. |
| Settings | `MailEnabled` | `true` | IMAP con GreenMail; `false` usa el buzón simulado. |
| Settings | `MailHost` | `127.0.0.1` | Servidor IMAP (contenedor `autofinops_mail`). |
| Settings | `MailPort` | `3143` | Puerto IMAP de GreenMail, sin TLS (solo desarrollo). |
| Settings | `MailFolder` | `INBOX` | Selecciona la carpeta IMAP. |
| Settings | `MailCredentialAssetName` | `Mail_Credential` | Selecciona el Asset de correo. |
| Settings | `MailSubjectFilter` | `Factura\|Invoice\|Cobro` | Filtra asuntos mediante Regex. |
| Settings | `ReportFolder` | `Data\Output\Reports` | Conserva el Excel diario. |
| Settings | `ReportRecipient` | `gerencia@autofinops.test` | Recibe el HTML y el Excel adjunto. |
| Settings | `SmtpHost` | `127.0.0.1` | Selecciona SMTP de GreenMail. |
| Settings | `SmtpPort` | `3025` | Selecciona el puerto SMTP local. |
| Constants | `MaxRetryNumber` | `0` | Desactiva los reintentos transaccionales locales. |
| Constants | `MaxConsecutiveSystemExceptions` | `0` | Conserva el valor de la plantilla. |
| Constants | `ExScreenshotsFolderPath` | `Exceptions_Screenshots` | Define la carpeta de capturas del framework. |
| Constants | `LogMessage_GetTransactionData` | `Processing Transaction Number: ` | Define el mensaje de transacción. |
| Constants | `LogMessage_GetTransactionDataError` | `Error getting transaction data for Transaction Number: ` | Define el mensaje de recuperación fallida. |
| Constants | `LogMessage_Success` | `Transaction Successful.` | Define el mensaje de éxito. |
| Constants | `LogMessage_BusinessRuleException` | `Business rule exception.` | Define el mensaje de negocio. |
| Constants | `LogMessage_ApplicationException` | `System exception.` | Define el mensaje técnico. |
| Constants | `ExceptionMessage_ConsecutiveErrors` | `The maximum number of consecutive system exceptions was reached. ` | Define el mensaje de límite. |
| Constants | `RetryNumberGetTransactionItem` | `2` | Reintenta la recuperación del elemento. |
| Constants | `RetryNumberSetTransactionStatus` | `2` | Configura el reintento de actualización del estado. |
| Constants | `ShouldMarkJobAsFaulted` | `false` | Conserva la política del framework. |
| Constants | `IvaRate` | `0.15` | Define el IVA demostrativo. |
| Constants | `IrRate` | `0.02` | Define la retención IR demostrativa. |
| Constants | `IrThresholdNio` | `1000.00` | Define el umbral estricto de IR. |
| Constants | `TaxTolerance` | `0.05` | Define la tolerancia fiscal. |

Configura `Invoices_Queue` en `Shared` con referencia única, auto-retry y `Max retries = 2`.
Distingue esos dos reintentos de `MaxRetryNumber=0` en el archivo local.
Usa Orchestrator como propietario del reintento transaccional técnico.
Espera hasta tres intentos por elemento cuando procedan ambos reintentos técnicos.
Distingue los reintentos de recuperación del elemento del reprocesamiento de la factura.

## Dispatcher.xaml: segundo entry point

Observa el Dispatcher sin argumentos públicos declarados.
Identifica este recorrido existente:

1. Carga `Data\Config.json` mediante `InitAllSettings`.
2. Crea la carpeta indicada por `PendingFolder`.
3. Consulta IMAP cuando `MailEnabled=true`.
4. Recupera `Mail_Credential` mediante `Get Credential` para esa rama.
5. Recupera hasta 30 correos no leídos con SSL y `MarkAsRead=True`.
6. Filtra asuntos con `MailSubjectFilter` sin distinguir mayúsculas.
7. Guarda adjuntos PDF directamente en `Data\Input\Pending` con sobrescritura habilitada.
8. Usa `Data\Input\Inbox` cuando `MailEnabled=false`.
9. Mueve cada PDF del buzón simulado a `Data\Input\Pending` con sobrescritura habilitada.
10. Recorre los PDF pendientes y ejecuta `Add Queue Item` por archivo.

| Propiedad del QueueItem | Valor existente |
| :--- | :--- |
| Cola | `Invoices_Queue` mediante `OrchestratorQueueName`. |
| Carpeta | `Shared` mediante `OrchestratorQueueFolder`. |
| `Reference` | Nombre del PDF sin extensión. |
| `SpecificContent("FilePath")` | Ruta absoluta del PDF pendiente. |
| `SpecificContent("FileName")` | Nombre del PDF con extensión. |

Comprueba el aviso de log cuando falle `Add Queue Item`.
Distingue ese aviso de una confirmación de encolado.
Conserva nombres de archivo distintos para las pruebas independientes.
Considera la sobrescritura de archivos homónimos en ambas ramas.
Considera que IMAP marca los correos leídos durante la recuperación.
No atribuyas confirmación posterior al encolado ni reintentos IMAP propios a este workflow.

## Framework/GetTransactionData.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_TransactionNumber` | `Int32` |
| In | `in_Config` | `Dictionary(Of String, Object)` |
| Out | `out_TransactionItem` | `UiPath.Core.QueueItem` |
| Out | `out_TransactionField1` | `String` |
| Out | `out_TransactionField2` | `String` |
| Out | `out_TransactionID` | `String` |
| In/Out | `io_dt_TransactionData` | `System.Data.DataTable` |

Observa `Get Transaction Item` sobre la cola y carpeta configuradas.
Identifica `RetryScope` con `RetryNumberGetTransactionItem` para recuperar el elemento.
Comprueba `out_TransactionID` igual a `Reference` cuando exista elemento.
Comprueba `out_TransactionField1` igual a `FileName` cuando exista esa clave.
Comprueba `out_TransactionField2` vacío.
Interpreta `out_TransactionItem=Nothing` como ausencia de trabajo para el framework.

## Framework/Process.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_TransactionItem` | `UiPath.Core.QueueItem` |
| In | `in_Config` | `Dictionary(Of String, Object)` |

### Recorrido existente por intento

1. Registra la hora inicial mediante `DateTime.Now`.
2. Lee `SpecificContent("FilePath")` y obtiene el nombre desde esa ruta.
3. Usa `Reference` como `queue_item_id`; usa el nombre cuando falte referencia.
4. Recupera `PG_Credential` y conecta mediante ODBC con `ConnectionSecureString`.
5. Invoca `Extract_Invoice_PDF` para obtener los campos escalares.
6. Invoca `Get_BCN_ExchangeRate` con la fecha de emisión.
7. Invoca `Validate_Tax_Rules` con conexión, configuración y campos extraídos.
8. Construye `in_Invoice` como `Dictionary(Of String, Object)` para `Insert_PostgreSQL`.
9. Solicita factura y auditoría; omite la factura cuando detecte `RECHAZADA_DUPLICADA`.
10. Mueve `CONCILIADA` a `Data\Output\Processed`.
11. Mueve los demás estados a `Data\Output\Business_Exceptions`.
12. Lanza `BusinessRuleException` después del movimiento cuando el estado difiera de `CONCILIADA`.
13. Cierra la conexión mediante `Disconnect` dentro de `Finally`.

### Excepciones y auditoría

Comprueba una fila en `rpa_audit_logs` para cada intento con persistencia disponible.
Usa `SUCCESS` y `exception_type=NULL` para la conciliación.
Usa `BUSINESS_EXCEPTION` y `exception_type=BRE` para los rechazos de negocio.
Observa `auditWritten` para evitar repetir la auditoría BRE ya registrada.
Ante BRE-04, observa la auditoría sin factura y el movimiento a excepciones de negocio.
Condiciona esa rama a una conexión disponible y una auditoría completada.

Usa `SYSTEM_EXCEPTION` y `exception_type=SE` para fallos técnicos.
Identifica la auditoría SE como best effort cuando exista conexión.
Conserva el código inicial `SE-` del mensaje; usa `SE-00` cuando falte.
Observa el aviso cuando falle la auditoría SE.
Propaga la excepción técnica hacia el framework.
Conserva el PDF pendiente durante ese recorrido técnico.
No atribuyas movimiento técnico final ni recuperación automática de auditoría al workflow.

Mide `duration_ms` hasta la invocación de persistencia mediante diferencia de horas.
Distingue `queue_item_id` de un identificador numérico de Orchestrator.
Considera una segunda auditoría SE si falla el movimiento después de auditar el resultado.

## Workflows/Extract_Invoice_PDF.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_FilePath` | `String` |
| Out | `out_InvoiceNumber` | `String` |
| Out | `out_Ruc` | `String` |
| Out | `out_ProviderName` | `String` |
| Out | `out_Currency` | `String` |
| Out | `out_IssueDate` | `DateTime` |
| Out | `out_Subtotal` | `Decimal` |
| Out | `out_Iva` | `Decimal` |
| Out | `out_Total` | `Decimal` |

Observa `Read PDF Text` sobre todas las páginas.
Identifica las expresiones Regex para proveedor, número, RUC, moneda, fecha e importes.
Usa etiquetas `Factura No:`, `RUC:`, `Moneda:`, `Fecha:`, `Subtotal:`, `IVA:` y `Total:`.
Reconoce únicamente USD o NIO mediante el patrón de moneda.
Observa `ParseExact` con fecha `yyyy-MM-dd` e `InvariantCulture`.
Observa la eliminación de comas antes de `Decimal.Parse` con `InvariantCulture`.
Usa documentos compatibles con ese formato numérico.
Distingue los argumentos escalares del diccionario construido posteriormente en Process.

Comprueba BRE-04 cuando falten número, RUC, moneda, fecha o total.
Interpreta BRE-04 como «el PDF no contiene los campos de una factura».
Distingue los errores de conversión de subtotal o IVA de esa comprobación BRE-04.
Trata los errores de lectura y conversión como fallos técnicos propagados.
No atribuyas OCR ni extracción de concepto a este workflow.

## Workflows/Get_BCN_ExchangeRate.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_IssueDate` | `DateTime` |
| In | `in_Config` | `Dictionary(Of String, Object)` |
| Out | `out_ExchangeRate` | `Decimal` |

Observa `HTTP Request` POST con cuerpo SOAP para `RecuperaTC_Dia`.
Usa `BcnServiceUrl` como endpoint y `BcnTimeoutMs` como timeout en milisegundos.
Identifica `Ano`, `Mes` y `Dia` desde `in_IssueDate`.
Conserva namespace `http://servicios.bcn.gob.ni/` y contenido `text/xml`, codificado UTF-8.
Conserva SOAPAction `http://servicios.bcn.gob.ni/RecuperaTC_Dia`.
Identifica `RetryPolicyType=None` como ausencia de reintento HTTP interno.

Comprueba HTTP 200 antes de interpretar el XML.
Observa `XDocument.Parse` y selección por nombre local `RecuperaTC_DiaResult`.
Observa `Decimal.Parse` con `InvariantCulture` para convertir la respuesta.
Comprueba SE-01 ante respuesta no disponible, estado distinto de 200 o tasa no positiva.
Trata errores de transporte, XML o conversión como excepciones técnicas propagadas.
No atribuyas un código SE-01 explícito a todos esos errores.

Conserva la respuesta de referencia informada para `RecuperaTC_Dia(2026, 10, 20)`:

```xml
<RecuperaTC_DiaResult>36.6243</RecuperaTC_DiaResult>
```

Distingue esa respuesta informada de una ejecución realizada durante esta revisión documental.
No uses una tasa fija como sustitución automática del servicio.

## Workflows/Validate_Tax_Rules.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_Connection` | `UiPath.Database.DatabaseConnection` |
| In | `in_Config` | `Dictionary(Of String, Object)` |
| In | `in_InvoiceNumber` | `String` |
| In | `in_Ruc` | `String` |
| In | `in_ProviderNamePdf` | `String` |
| In | `in_Currency` | `String` |
| In | `in_Subtotal` | `Decimal` |
| In | `in_Iva` | `Decimal` |
| In | `in_Total` | `Decimal` |
| In | `in_ExchangeRate` | `Decimal` |
| Out | `out_Status` | `String` |
| Out | `out_ErrorCode` | `String` |
| Out | `out_Notes` | `String` |
| Out | `out_ProviderName` | `String` |
| Out | `out_CostCenter` | `String` |
| Out | `out_IrNio` | `Decimal` |
| Out | `out_NetNio` | `Decimal` |
| Out | `out_NetUsd` | `Decimal` |

Observa dos actividades `Run Query` con marcadores posicionales `?`:

```sql
SELECT legal_name, cost_center, is_tax_exempt
FROM providers
WHERE provider_ruc = ? AND active = TRUE;

SELECT 1 AS existe
FROM invoices_reconciliation
WHERE provider_ruc = ? AND invoice_number = ?;
```

Comprueba el orden RUC, número en la consulta de duplicidad.
Observa `Invoke Code` para aplicar RF-05.
Obtén nombre, centro de costo y exención desde el proveedor activo.
Identifica `Sin clasificar` como centro de costo cuando falte proveedor.
Prioriza BRE-03, después BRE-01 y finalmente BRE-02.

Aplica `IvaRate`, `IrRate`, `IrThresholdNio` y `TaxTolerance` desde configuración.
Comprueba suma e IVA mediante tolerancia absoluta.
Calcula IVA cero para proveedores exentos.
Calcula IR únicamente para `CONCILIADA`, proveedor no exento y subtotal NIO superior a 1000.
Conserva IR cero para los demás resultados.
Calcula netos NIO y USD con redondeo `MidpointRounding.AwayFromZero` a dos decimales.
Distingue el resultado devuelto de la excepción lanzada posteriormente por Process.

Conserva `Sin clasificar` en las observaciones BRE-01.
Distingue el CHECK de `providers.cost_center` de la columna contable sin ese CHECK.
No atribuyas clasificación por concepto a este workflow.

## Workflows/Insert_PostgreSQL.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_Connection` | `UiPath.Database.DatabaseConnection` |
| In | `in_WriteInvoice` | `Boolean` |
| In | `in_InvoiceNumber` | `String` |
| In | `in_Invoice` | `Dictionary(Of String, Object)` |
| In | `in_QueueItemId` | `String` |
| In | `in_BotStage` | `String` |
| In | `in_AuditStatus` | `String` |
| In | `in_ExceptionType` | `String` |
| In | `in_ErrorCode` | `String` |
| In | `in_ErrorMessage` | `String` |
| In | `in_DurationMs` | `Int32` |

Observa el INSERT contable cuando `in_WriteInvoice=True`.
Respeta este orden del diccionario y los 16 parámetros posicionales `?`:

| Posición | Clave de `in_Invoice` | Tipo enviado |
| :--- | :--- | :--- |
| 1 | `invoice_number` | `String` |
| 2 | `provider_ruc` | `String` |
| 3 | `provider_name` | `String` |
| 4 | `cost_center` | `String` |
| 5 | `issue_date` | `DateTime.Date` |
| 6 | `original_currency` | `String` |
| 7 | `exchange_rate_bcn` | `Decimal` |
| 8 | `subtotal_original` | `Decimal` |
| 9 | `iva_amount_original` | `Decimal` |
| 10 | `total_original` | `Decimal` |
| 11 | `ir_retention_nio` | `Decimal` |
| 12 | `net_payable_nio` | `Decimal` |
| 13 | `net_payable_usd` | `Decimal` |
| 14 | `reconciliation_status` | `String` |
| 15 | `validation_notes` | `String` |
| 16 | `pdf_file_name` | `String` |

Observa después el INSERT parametrizado de auditoría:

```sql
INSERT INTO rpa_audit_logs (
    queue_item_id, invoice_number, bot_stage, status, duration_ms,
    exception_type, error_code, error_message
) VALUES (?, NULLIF(?, ''), ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?);
```

Comprueba `NULLIF` para número, tipo de excepción y código vacíos.
Usa `in_WriteInvoice=False` para duplicados y auditoría sin factura.
Conserva la factura existente cuando Validate detecte BRE-03.
Deja los identificadores y fechas automáticos bajo responsabilidad de PostgreSQL.
Distingue los dos comandos secuenciales de una transacción atómica explícita.
No atribuyas rollback, recuperación del identificador ni clasificación de SQLSTATE a este workflow.

## Workflows/Send_Daily_Report.xaml

### Argumentos existentes

| Dirección | Argumento | Tipo |
| :--- | :--- | :--- |
| In | `in_Config` | `Dictionary(Of String, Object)` |

Identifica RF-07 como implementado.
Observa la invocación desde `End Process` de `Main.xaml`, después de `CloseAllApplications`.
Pasa `Config` como `in_Config` cuando `Config IsNot Nothing`.
Captura errores mediante `TryCatch`; registra `Warn` sin detener el proceso.

### Actividades en orden

1. Crea `ReportFolder` mediante `Create Folder`.
2. Asigna `reportPath` mediante `Assign` con nombre `Reporte_Conciliacion_yyyyMMdd.xlsx`.
3. Recupera `PG_Credential` mediante `Get Credential` en `Shared`.
4. Abre ODBC mediante `Connect`, `PostgreSqlDsn` y `ConnectionSecureString`.
5. Ejecuta `Run Query` sobre `invoices_reconciliation`, filtrando `processed_at::date = CURRENT_DATE`.
6. Ejecuta `Run Query` sobre `rpa_audit_logs`, filtrando `logged_at::date = CURRENT_DATE`.
7. Agrupa auditoría por `COALESCE(error_code, 'SUCCESS')` y cuenta intentos.
8. Cierra ODBC mediante `Disconnect` dentro de `Finally`, cuando exista conexión.
9. Comprueba `dt_Report IsNot Nothing AndAlso dt_Report.Rows.Count > 0`.
10. Escribe `dt_Report` mediante `Write Range Workbook`, con encabezados desde `A1`.
11. Usa `Data\Output\Reports\Reporte_Conciliacion_yyyyMMdd.xlsx`, hoja `Conciliacion`, sin Excel instalado.
12. Construye el resumen HTML mediante `Invoke Code`.
13. Recupera `Mail_Credential` mediante `Get Credential` en `Shared`.
14. Envía HTML a `ReportRecipient` mediante `Send SMTP Email`, con el Excel adjunto.
15. Usa `SmtpHost`, `SmtpPort` y las credenciales del Asset para SMTP.
16. Registra el envío mediante `Log Message` con nivel `Info`.

Incluye tarjetas de conciliadas, observadas, duplicadas BRE-03 y neto aprobado.
Cuenta duplicadas desde auditoría; suma neto aprobado únicamente para facturas conciliadas.
Incluye tabla de facturas con estados en color.
Usa el asunto `AutoFinOps-NI | Reporte de conciliacion yyyy-MM-dd` con la fecha actual.
Omite Excel y correo cuando no existan facturas del día; registra `Info`.
Considera ambos filtros diarios según `CURRENT_DATE` de PostgreSQL.

### Prueba manual

1. Comprueba PostgreSQL y GreenMail del entorno local.
2. Comprueba `PG_Credential`, `Mail_Credential` y el DSN bajo la cuenta del robot.
3. Comprueba `ReportFolder`, `ReportRecipient`, `SmtpHost` y `SmtpPort` en `Data/Config.json`.
4. Procesa facturas ficticias del día y termina el Performer normalmente.
5. Comprueba el archivo diario en `Data\Output\Reports` y la hoja `Conciliacion`.
6. Consulta el buzón GreenMail de `ReportRecipient` mediante IMAP local, puerto `3143`.
7. Comprueba asunto, tarjetas HTML, tabla de estados y Excel adjunto.
8. Compara las filas del Excel con las facturas seleccionadas por el filtro diario.

Conserva la evidencia verificada del 2026-10-28:

| Evidencia | Resultado |
| :--- | :--- |
| Buzón receptor | `gerencia@autofinops.test` en GreenMail. |
| Asunto | `AutoFinOps-NI \| Reporte de conciliacion 2026-10-28` |
| HTML | 11,811 caracteres. |
| Excel adjunto | 8,072 bytes; 19 filas. |

Distingue esta evidencia informada de una nueva ejecución durante esta actualización documental.

## Publicar en Orchestrator

Usa una sesión autenticada de `uip` con acceso al tenant correspondiente.
Ejecuta desde `C:\Proyectos\Personal\autofinops-rpa-engine\uipath_workflow`.
Consulta la ayuda para completar los argumentos exigidos por la versión instalada:

```powershell
uip rpa pack --help
uip or packages upload --help
uip or processes create --help
```

Completa cada comando con los argumentos indicados por esa ayuda.
Usa esta secuencia y los valores de la tabla:

```powershell
uip rpa pack
uip or packages upload
uip or processes create
uip or processes create
```

| Comando | Valores para completar argumentos |
| :--- | :--- |
| `uip rpa pack` | Proyecto actual; paquete `AutoFinOps-NI`; versión `1.0.0`; salida `AutoFinOps-NI.1.0.0.nupkg`. |
| `uip or packages upload` | Archivo `AutoFinOps-NI.1.0.0.nupkg` generado por `pack`. |
| Primer `uip or processes create` | Carpeta `Shared`; nombre `AutoFinOps-NI Dispatcher`; paquete `AutoFinOps-NI`; versión `1.0.0`; entry point `Dispatcher.xaml`. |
| Segundo `uip or processes create` | Carpeta `Shared`; nombre `AutoFinOps-NI Performer`; paquete `AutoFinOps-NI`; versión `1.0.0`; entry point `Main.xaml`. |

Conserva la publicación verificada del paquete y ambos procesos del 2026-10-28.
Conserva el bloque `ReadPDFText.Item`, con `ItemArgument` y `FileName`, antes de empaquetar.
Reconoce esa exigencia de `uip rpa pack`, ausente durante `build`.

### Runtime para ejecutar

Registra HTTP 409 al iniciar el job desde Orchestrator durante la prueba verificada:

```text
Could not find a machine with Unattended or NonProduction runtimes
```

Identifica el tenant probado con robot atendido únicamente.
Ejecuta `AutoFinOps-NI Dispatcher` y `AutoFinOps-NI Performer` desde UiPath Assistant.
Asigna runtime `Unattended` para ejecutar mediante Queue Trigger.
Distingue publicación completada de ejecución desatendida bloqueada por disponibilidad de runtime.

## Pruebas con uip rpa run

Usa una sesión del robot con acceso a Orchestrator y PostgreSQL.
Comprueba `PG_Credential`, el DSN de usuario y la cola antes de ejecutar.
Ejecuta desde la carpeta del proyecto:

```powershell
Set-Location C:\Proyectos\Personal\autofinops-rpa-engine\uipath_workflow
uip rpa run --help
```

Confirma los parámetros de proyecto y selección de entry point mediante esa ayuda.
Ejecuta `uip rpa run` con `Dispatcher.xaml` seleccionado como segundo entry point.
Ejecuta después `uip rpa run` con el entry point principal del Performer.
Usa las opciones publicadas por tu CLI para ambas selecciones.
Evita inventar argumentos públicos para Dispatcher o Process.

1. Prepara PDF ficticios con nombres distintos en `Data\Input\Inbox`.
2. Comprueba `MailEnabled=false` para la prueba del buzón simulado.
3. Ejecuta Dispatcher y comprueba un QueueItem por PDF pendiente.
4. Comprueba `Reference`, `FilePath` y `FileName` en la cola `Shared/Invoices_Queue`.
5. Ejecuta Performer y consulta las filas contables y de auditoría.
6. Prueba TeleRed con número nuevo: subtotal 4200, IVA 630 y total 4830.
7. Comprueba IR 84, neto NIO 4746 y carpeta `Data\Output\Processed`.
8. Prueba IVA incorrecto con número nuevo y comprueba BRE-02.
9. Prueba una factura semilla existente y comprueba BRE-03 sin segunda factura.
10. Prueba un PDF sin campos de factura y comprueba BRE-04.
11. Comprueba auditoría BRE y carpeta `Data\Output\Business_Exceptions` para BRE-04.
12. Prueba BCN no disponible y comprueba auditoría SE cuando exista conexión.
13. Comprueba hasta dos reintentos automáticos técnicos en Orchestrator.
14. Prueba PostgreSQL no disponible y distingue la auditoría best effort de una fila confirmada.
15. Prueba RUC ausente y comprueba BRE-01 con centro de costo `Sin clasificar`.

Usa números nuevos para las pruebas fiscales que deban evitar los registros semilla.
Usa otro nombre de archivo para probar duplicidad contable sin bloquear la referencia única.
Comprueba NubeCentro exento sin IVA ni IR con datos compatibles.

## Límites de verificación

Distingue la inspección estática de una ejecución integrada del robot.
Conserva plantilla, paquetes, Studio y driver como datos del entorno declarado.
Verifica esos datos operativos fuera de la lista de archivos revisados antes de certificar instalaciones.
Conserva RF-07 y publicación como hechos verificados informados del 2026-10-28.
No atribuyas nuevas ejecuciones a esta actualización documental.
No atribuyas recuperación automática de auditoría ni movimiento final técnico al bot actual.
Registra cualquier impedimento de `uip rpa run` antes de afirmar una ejecución correcta.
