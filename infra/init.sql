-- ============================================================================
-- PROYECTO: AutoFinOps-NI | Esquema Relacional PostgreSQL 17
-- Autor: Norman Martinez (NormanSMA)
-- Datos de demostracion: proveedores, RUC y montos son ficticios.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Catalogo de Proveedores Autorizados
CREATE TABLE providers (
    provider_id SERIAL PRIMARY KEY,
    provider_ruc VARCHAR(25) UNIQUE NOT NULL,
    legal_name VARCHAR(150) NOT NULL,
    cost_center VARCHAR(60) NOT NULL CHECK (cost_center IN (
        'Cloud & Infraestructura TI',
        'Servicios Públicos & Telecom',
        'Honorarios Legales & Admin',
        'Suministros Operativos'
    )),
    is_tax_exempt BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla Principal de Conciliacion de Facturas
-- Estados unificados con RF-06. El motivo concreto (BRE-01, BRE-02) va en validation_notes.
CREATE TABLE invoices_reconciliation (
    reconciliation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number VARCHAR(50) NOT NULL,
    provider_ruc VARCHAR(25) NOT NULL,
    provider_name VARCHAR(150) NOT NULL,
    cost_center VARCHAR(60) NOT NULL,
    issue_date DATE NOT NULL,
    original_currency CHAR(3) NOT NULL CHECK (original_currency IN ('USD', 'NIO')),
    exchange_rate_bcn NUMERIC(10, 4) NOT NULL,
    subtotal_original NUMERIC(12, 2) NOT NULL,
    iva_amount_original NUMERIC(12, 2) NOT NULL,
    total_original NUMERIC(12, 2) NOT NULL,
    ir_retention_nio NUMERIC(12, 2) DEFAULT 0.00,
    net_payable_nio NUMERIC(12, 2) NOT NULL,
    net_payable_usd NUMERIC(12, 2) NOT NULL,
    reconciliation_status VARCHAR(35) NOT NULL CHECK (reconciliation_status IN (
        'CONCILIADA',
        'OBSERVADA_REGLA_NEGOCIO',
        'RECHAZADA_DUPLICADA'
    )),
    validation_notes TEXT,
    pdf_file_name VARCHAR(255) NOT NULL,
    processed_by_bot VARCHAR(60) DEFAULT 'UiPath_AutoFinOps_Performer_v1',
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_provider_invoice UNIQUE (provider_ruc, invoice_number)
);

-- 3. Bitacora de Auditoria y Telemetria del Robot (columnas segun RNF-04)
CREATE TABLE rpa_audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    queue_item_id VARCHAR(100) NOT NULL,
    invoice_number VARCHAR(50),
    bot_stage VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL CHECK (status IN (
        'SUCCESS',
        'BUSINESS_EXCEPTION',
        'SYSTEM_EXCEPTION'
    )),
    duration_ms INTEGER NOT NULL,
    exception_type VARCHAR(3) CHECK (exception_type IN ('BRE', 'SE')),
    error_code VARCHAR(40),
    error_message TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Vista Ejecutiva para Dashboard en Power BI / Metabase
CREATE OR REPLACE VIEW vw_finops_kpis AS
SELECT
    COUNT(*) AS total_facturas_procesadas,
    COUNT(*) FILTER (WHERE reconciliation_status = 'CONCILIADA') AS facturas_conciliadas_ok,
    COUNT(*) FILTER (WHERE reconciliation_status LIKE 'OBSERVADA%') AS facturas_con_alerta,
    ROUND(
        (COUNT(*) FILTER (WHERE reconciliation_status = 'CONCILIADA')::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
        2
    ) AS porcentaje_exito_conciliacion,
    SUM(net_payable_nio) FILTER (WHERE reconciliation_status = 'CONCILIADA') AS total_aprobado_cordobas,
    SUM(net_payable_usd) FILTER (WHERE reconciliation_status = 'CONCILIADA') AS total_aprobado_dolares,
    SUM(ir_retention_nio) FILTER (WHERE reconciliation_status = 'CONCILIADA') AS total_retencion_ir_nio,
    -- Estimacion de ahorro operativo: 4.5 min manuales vs 5 seg en RPA
    ROUND((COUNT(*) * 4.41) / 60.0, 2) AS horas_humanas_ahorradas
FROM invoices_reconciliation;

-- 5. Datos Semilla (proveedores ficticios de demostracion)
INSERT INTO providers (provider_ruc, legal_name, cost_center, is_tax_exempt) VALUES
('J0310000102938', 'NubeCentro Hosting LLC', 'Cloud & Infraestructura TI', TRUE),
('J0310000001122', 'TeleRed Nicaragua S.A.', 'Servicios Públicos & Telecom', FALSE),
('J0310000445566', 'Bufete Ríos & Asociados S.A.', 'Honorarios Legales & Admin', FALSE),
('J0310000889900', 'Suministros El Roble S.A.', 'Suministros Operativos', FALSE),
('J0310000773311', 'DataPinos S.A.', 'Cloud & Infraestructura TI', FALSE);

-- 6. Registros Iniciales de Prueba
INSERT INTO invoices_reconciliation (
    invoice_number, provider_ruc, provider_name, cost_center, issue_date,
    original_currency, exchange_rate_bcn, subtotal_original, iva_amount_original,
    total_original, ir_retention_nio, net_payable_nio, net_payable_usd,
    reconciliation_status, validation_notes, pdf_file_name
) VALUES
('FAC-2026-0891', 'J0310000102938', 'NubeCentro Hosting LLC', 'Cloud & Infraestructura TI', '2026-10-20', 'USD', 36.6243, 185.00, 0.00, 185.00, 0.00, 6775.50, 185.00, 'CONCILIADA', 'Servicio cloud internacional - Exento de IVA local.', 'INV_NubeCentro_2026_10.pdf'),
('FAC-2026-4410', 'J0310000001122', 'TeleRed Nicaragua S.A.', 'Servicios Públicos & Telecom', '2026-10-22', 'NIO', 36.6243, 4200.00, 630.00, 4830.00, 84.00, 4746.00, 129.59, 'CONCILIADA', 'IVA 15% validado y Retención IR 2% aplicada correctamente.', 'Factura_TeleRed_Oct2026.pdf'),
('FAC-2026-1029', 'J0310000445566', 'Bufete Ríos & Asociados S.A.', 'Honorarios Legales & Admin', '2026-10-24', 'USD', 36.6243, 350.00, 52.50, 402.50, 256.37, 14484.91, 395.50, 'CONCILIADA', 'Conversión USD a NIO con tasa oficial BCN y retención IR.', 'Factura_RiosAsociados_1029.pdf'),
('FAC-2026-9902', 'J0310000889900', 'Suministros El Roble S.A.', 'Suministros Operativos', '2026-10-25', 'NIO', 36.6243, 2500.00, 200.00, 2700.00, 0.00, 2700.00, 73.72, 'OBSERVADA_REGLA_NEGOCIO', 'BRE-02: El IVA cobrado (C$ 200.00) no coincide con el 15% legal (C$ 375.00). Enviado a revisión humana.', 'Factura_Suministros_ErrorIVA.pdf');

INSERT INTO rpa_audit_logs (queue_item_id, invoice_number, bot_stage, status, duration_ms, exception_type, error_code, error_message) VALUES
('Q-20261027-001', 'FAC-2026-0891', 'End_Process', 'SUCCESS', 4120, NULL, NULL, 'Conciliada e insertada en PostgreSQL 17.'),
('Q-20261027-002', 'FAC-2026-4410', 'End_Process', 'SUCCESS', 4890, NULL, NULL, 'Conciliada con cálculo automático de IR 2%.'),
('Q-20261027-003', 'FAC-2026-1029', 'End_Process', 'SUCCESS', 5110, NULL, NULL, 'Conciliada con conversión cambiaria USD->NIO.'),
('Q-20261027-004', 'FAC-2026-9902', 'Tax_Validation', 'BUSINESS_EXCEPTION', 3250, 'BRE', 'BRE-02', 'Discrepancia detectada entre Subtotal * 0.15 e IVA declarado en PDF.');
