IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'PlanillaObrera')
BEGIN
    CREATE DATABASE PlanillaObrera;
END
GO

USE PlanillaObrera;
GO

-- ============================================================
-- CATÁLOGOS (llaves NO identity, excepto Puesto)
-- ============================================================

-- ============================================================
-- TABLA: TipoDocIdentidad
-- DESCRIPCIÓN: Catálogo estático de los tipos de documentos
--              de identificación válidos (Cédula, DIMEX, etc.).
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TipoDocIdentidad')
CREATE TABLE dbo.TipoDocIdentidad (
    Id     INT          NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_TipoDocIdentidad PRIMARY KEY (Id)
);
GO

-- ============================================================
-- TABLA: Puesto
-- DESCRIPCIÓN: Almacena los diferentes puestos laborales con su
--              respectivo salario base por hora para los cálculos.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Puesto')
CREATE TABLE dbo.Puesto (
    Id           INT          NOT NULL IDENTITY(1,1),
    Nombre       VARCHAR(100) NOT NULL,
    SalarioXHora MONEY        NOT NULL,
    CONSTRAINT PK_Puesto        PRIMARY KEY (Id),
    CONSTRAINT UQ_Puesto_Nombre UNIQUE (Nombre)
);
GO

-- ============================================================
-- TABLA: Departamento
-- DESCRIPCIÓN: Catálogo de los departamentos u áreas operativas
--              en las que se organiza la empresa.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Departamento')
CREATE TABLE dbo.Departamento (
    Id     INT          NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Departamento PRIMARY KEY (Id)
);
GO

-- ============================================================
-- TABLA: TipoJornada
-- DESCRIPCIÓN: Define los tipos de turnos de trabajo existentes
--              con sus respectivas horas de inicio y fin.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TipoJornada')
CREATE TABLE dbo.TipoJornada (
    Id         INT          NOT NULL,
    Nombre     VARCHAR(100) NOT NULL,
    HoraInicio TIME          NOT NULL,
    HoraFin    TIME          NOT NULL,
    CONSTRAINT PK_TipoJornada PRIMARY KEY (Id)
);
GO

-- ============================================================
-- TABLA: TipoMovimiento
-- DESCRIPCIÓN: Catálogo que rige si un movimiento de planilla
--              suma (+) o resta (-) al salario del empleado.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TipoMovimiento')
CREATE TABLE dbo.TipoMovimiento (
    Id     INT          NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Accion CHAR(1)      NOT NULL,
    CONSTRAINT PK_TipoMovimiento        PRIMARY KEY (Id),
    CONSTRAINT CK_TipoMovimiento_Accion CHECK (Accion IN ('+', '-'))
);
GO

-- ============================================================
-- TABLA: TipoDeduccion
-- DESCRIPCIÓN: Configura las deducciones (CCSS, renta, etc.),
--              su valor, si es fija/porcentual u obligatoria.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TipoDeduccion')
CREATE TABLE dbo.TipoDeduccion (
    Id               INT           NOT NULL,
    Nombre           VARCHAR(100)  NOT NULL,
    EsObligatoria    BIT           NOT NULL,
    EsPorcentual     BIT           NOT NULL,
    Valor            DECIMAL(10,4) NOT NULL DEFAULT 0,
    IdTipoMovimiento INT           NOT NULL,
    CONSTRAINT PK_TipoDeduccion PRIMARY KEY (Id),
    CONSTRAINT FK_TipoDeduccion_TipoMovimiento
        FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento(Id)
);
GO

-- ============================================================
-- TABLA: TipoEvento
-- DESCRIPCIÓN: Catálogo con la clasificación de eventos para el
--              control de auditoría en la bitácora del sistema.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TipoEvento')
CREATE TABLE dbo.TipoEvento (
    Id     INT          NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_TipoEvento PRIMARY KEY (Id)
);
GO

-- ============================================================
-- TABLA: Feriado
-- DESCRIPCIÓN: Registro de los días festivos del año para el
--              cálculo correcto del pago de horas dobles.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Feriado')
CREATE TABLE dbo.Feriado (
    Id     INT          NOT NULL,
    Nombre VARCHAR(150) NOT NULL,
    Fecha  DATE         NOT NULL,
    CONSTRAINT PK_Feriado       PRIMARY KEY (Id),
    CONSTRAINT UQ_Feriado_Fecha UNIQUE (Fecha)
);
GO

-- ============================================================
-- TABLA: Usuario
-- DESCRIPCIÓN: Almacena las credenciales de acceso al sistema,
--              restringiendo el rol (administrador o empleado).
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Usuario')
CREATE TABLE dbo.Usuario (
    Id           INT          NOT NULL IDENTITY(1,1),
    Username     VARCHAR(100) NOT NULL,
    PasswordHash VARCHAR(256) NOT NULL,
    Tipo         VARCHAR(50)  NOT NULL,
    Activo       BIT          NOT NULL DEFAULT 1,
    CONSTRAINT PK_Usuario          PRIMARY KEY (Id),
    CONSTRAINT UQ_Usuario_Username UNIQUE (Username),
    CONSTRAINT CK_Usuario_Tipo     CHECK (Tipo IN ('administrador', 'empleado'))
);
GO

IF COL_LENGTH('dbo.Usuario', 'Activo') IS NULL
    ALTER TABLE dbo.Usuario ADD Activo BIT NOT NULL CONSTRAINT DF_Usuario_Activo DEFAULT 1;
GO

-- ============================================================
-- TABLA: Empleado
-- DESCRIPCIÓN: Contiene la información maestro y personal de los
--              colaboradores activos e inactivos de la empresa.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Empleado')
CREATE TABLE dbo.Empleado (
    Id                INT          NOT NULL IDENTITY(1,1),
    IdPuesto          INT          NOT NULL,
    IdDepartamento    INT          NOT NULL,
    IdTipoDocumento   INT          NOT NULL,
    IdUsuario         INT          NOT NULL,
    ValorDocumento    VARCHAR(50)  NOT NULL,
    Nombre            VARCHAR(200) NOT NULL,
    CuentaBancaria    VARCHAR(100) NOT NULL,
    FechaContratacion DATE         NOT NULL,
    Activo            BIT          NOT NULL DEFAULT 1,
    CONSTRAINT PK_Empleado                PRIMARY KEY (Id),
    CONSTRAINT UQ_Empleado_ValorDocumento UNIQUE (ValorDocumento),
    CONSTRAINT FK_Empleado_Puesto
        FOREIGN KEY (IdPuesto)        REFERENCES dbo.Puesto(Id),
    CONSTRAINT FK_Empleado_Departamento
        FOREIGN KEY (IdDepartamento)  REFERENCES dbo.Departamento(Id),
    CONSTRAINT FK_Empleado_TipoDoc
        FOREIGN KEY (IdTipoDocumento) REFERENCES dbo.TipoDocIdentidad(Id),
    CONSTRAINT FK_Empleado_Usuario
        FOREIGN KEY (IdUsuario)       REFERENCES dbo.Usuario(Id)
);
GO

-- ============================================================
-- TABLA: DeduccionEmpleado
-- DESCRIPCIÓN: Vincula de forma histórica las deducciones voluntarias
--              o fijas aplicadas a cada empleado específico.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeduccionEmpleado')
CREATE TABLE dbo.DeduccionEmpleado (
    Id              INT           NOT NULL IDENTITY(1,1),
    IdEmpleado      INT           NOT NULL,
    IdTipoDeduccion INT           NOT NULL,
    MontoFijo       DECIMAL(12,2) NOT NULL DEFAULT 0,
    FechaInicio     DATE          NOT NULL,
    FechaFin        DATE          NULL,
    CONSTRAINT PK_DeduccionEmpleado PRIMARY KEY (Id),
    CONSTRAINT FK_DeducEmp_Empleado
        FOREIGN KEY (IdEmpleado)      REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_DeducEmp_TipoDeduccion
        FOREIGN KEY (IdTipoDeduccion) REFERENCES dbo.TipoDeduccion(Id)
);
GO

-- ============================================================
-- TABLA: Mes
-- DESCRIPCIÓN: Delimita los rangos de fechas de los meses comerciales
--              y el conteo de jueves para cierres mensuales.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Mes')
CREATE TABLE dbo.Mes (
    Id          INT     NOT NULL IDENTITY(1,1),
    FechaInicio DATE    NOT NULL,
    FechaFin    DATE    NOT NULL,
    NumJueves   TINYINT NOT NULL,
    CONSTRAINT PK_Mes PRIMARY KEY (Id)
);
GO

-- ============================================================
-- TABLA: Semana
-- DESCRIPCIÓN: Divide los meses en periodos semanales de pago,
--              que es la base operativa de la planilla obrera.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Semana')
CREATE TABLE dbo.Semana (
    Id          INT  NOT NULL IDENTITY(1,1),
    IdMes       INT  NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin    DATE NOT NULL,
    CONSTRAINT PK_Semana PRIMARY KEY (Id),
    CONSTRAINT FK_Semana_Mes FOREIGN KEY (IdMes) REFERENCES dbo.Mes(Id)
);
GO

-- ============================================================
-- TABLA: HorarioJornada
-- DESCRIPCIÓN: Asocia la jornada que el empleado tiene asignada
--              para cumplir durante una semana específica.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'HorarioJornada')
CREATE TABLE dbo.HorarioJornada (
    Id            INT NOT NULL IDENTITY(1,1),
    IdEmpleado    INT NOT NULL,
    IdSemana      INT NOT NULL,
    IdTipoJornada INT NOT NULL,
    CONSTRAINT PK_HorarioJornada PRIMARY KEY (Id),
    CONSTRAINT UQ_HorarioJornada UNIQUE (IdEmpleado, IdSemana),
    CONSTRAINT FK_HorJor_Empleado
        FOREIGN KEY (IdEmpleado)    REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_HorJor_Semana
        FOREIGN KEY (IdSemana)      REFERENCES dbo.Semana(Id),
    CONSTRAINT FK_HorJor_TipoJornada
        FOREIGN KEY (IdTipoJornada) REFERENCES dbo.TipoJornada(Id)
);
GO

-- ============================================================
-- TABLA: MarcaAsistencia
-- DESCRIPCIÓN: Captura los timbrajes reales de entrada y salida
--              registrados diariamente por los obreros.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MarcaAsistencia')
CREATE TABLE dbo.MarcaAsistencia (
    Id               INT      NOT NULL IDENTITY(1,1),
    IdEmpleado       INT      NOT NULL,
    IdHorarioJornada INT      NOT NULL,
    Fecha            DATE     NOT NULL,
    HoraEntrada      DATETIME NOT NULL,
    HoraSalida       DATETIME NOT NULL,
    CONSTRAINT PK_MarcaAsistencia PRIMARY KEY (Id),
    CONSTRAINT FK_Marca_Empleado
        FOREIGN KEY (IdEmpleado)       REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_Marca_HorarioJornada
        FOREIGN KEY (IdHorarioJornada) REFERENCES dbo.HorarioJornada(Id)
);
GO

-- ============================================================
-- TABLA: PlanillaSemanal
-- DESCRIPCIÓN: Acumula los cálculos procesados de salarios brutos,
--              netos y distribución de horas semanales por obrero.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PlanillaSemanal')
CREATE TABLE dbo.PlanillaSemanal (
    Id               INT           NOT NULL IDENTITY(1,1),
    IdEmpleado       INT           NOT NULL,
    IdSemana         INT           NOT NULL,
    SalarioBruto     DECIMAL(14,2) NOT NULL DEFAULT 0,
    TotalDeducciones DECIMAL(14,2) NOT NULL DEFAULT 0,
    SalarioNeto      DECIMAL(14,2) NOT NULL DEFAULT 0,
    HorasOrdinarias  DECIMAL(8,2)  NOT NULL DEFAULT 0,
    HorasExtraNormal DECIMAL(8,2)  NOT NULL DEFAULT 0,
    HorasExtraDoble  DECIMAL(8,2)  NOT NULL DEFAULT 0,
    CONSTRAINT PK_PlanillaSemanal PRIMARY KEY (Id),
    CONSTRAINT UQ_PlanSem         UNIQUE (IdEmpleado, IdSemana),
    CONSTRAINT FK_PlanSem_Empleado
        FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_PlanSem_Semana
        FOREIGN KEY (IdSemana)   REFERENCES dbo.Semana(Id)
);
GO

-- ============================================================
-- TABLA: PlanillaMensual
-- DESCRIPCIÓN: Consolida la sumatoria de ingresos y egresos de un
--              empleado a lo largo de un mes para reportes estatales.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PlanillaMensual')
CREATE TABLE dbo.PlanillaMensual (
    Id               INT           NOT NULL IDENTITY(1,1),
    IdEmpleado       INT           NOT NULL,
    IdMes            INT           NOT NULL,
    SalarioBruto     DECIMAL(14,2) NOT NULL DEFAULT 0,
    TotalDeducciones DECIMAL(14,2) NOT NULL DEFAULT 0,
    SalarioNeto      DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_PlanillaMensual PRIMARY KEY (Id),
    CONSTRAINT UQ_PlanMen         UNIQUE (IdEmpleado, IdMes),
    CONSTRAINT FK_PlanMen_Empleado
        FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_PlanMen_Mes
        FOREIGN KEY (IdMes)      REFERENCES dbo.Mes(Id)
);
GO

-- ============================================================
-- TABLA: DeduccionXMes
-- DESCRIPCIÓN: Detalla el desglose total cobrado por cada tipo
--              de deducción en el cierre de la planilla mensual.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeduccionXMes')
CREATE TABLE dbo.DeduccionXMes (
    Id                INT           NOT NULL IDENTITY(1,1),
    IdPlanillaMensual INT           NOT NULL,
    IdTipoDeduccion   INT           NOT NULL,
    MontoTotal        DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_DeduccionXMes PRIMARY KEY (Id),
    CONSTRAINT UQ_DeducXMes     UNIQUE (IdPlanillaMensual, IdTipoDeduccion),
    CONSTRAINT FK_DeducXMes_PlanMen
        FOREIGN KEY (IdPlanillaMensual) REFERENCES dbo.PlanillaMensual(Id),
    CONSTRAINT FK_DeducXMes_TipoDeduccion
        FOREIGN KEY (IdTipoDeduccion)   REFERENCES dbo.TipoDeduccion(Id)
);
GO

-- ============================================================
-- TABLA: Comprobante
-- DESCRIPCIÓN: Encabezado de los entregables o recibos oficiales
--              generados al procesar los pagos de la planilla.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Comprobante')
CREATE TABLE dbo.Comprobante (
    Id                INT         NOT NULL IDENTITY(1,1),
    IdPlanillaSemanal INT         NOT NULL,
    Tipo              VARCHAR(50) NOT NULL,
    FechaHora         DATETIME    NOT NULL,
    CONSTRAINT PK_Comprobante PRIMARY KEY (Id),
    CONSTRAINT FK_Comprobante_PlanSem
        FOREIGN KEY (IdPlanillaSemanal) REFERENCES dbo.PlanillaSemanal(Id)
);
GO

-- ============================================================
-- TABLA: ComprobanteHora
-- DESCRIPCIÓN: Tabla intermedia que asocia las marcas de asistencia
--              específicas justificadas en un comprobante dado.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ComprobanteHora')
CREATE TABLE dbo.ComprobanteHora (
    Id                INT NOT NULL IDENTITY(1,1),
    IdComprobante     INT NOT NULL,
    IdMarcaAsistencia INT NOT NULL,
    CONSTRAINT PK_ComprobanteHora PRIMARY KEY (Id),
    CONSTRAINT UQ_ComprobanteHora UNIQUE (IdComprobante, IdMarcaAsistencia),
    CONSTRAINT FK_CompHora_Comprobante
        FOREIGN KEY (IdComprobante)     REFERENCES dbo.Comprobante(Id),
    CONSTRAINT FK_CompHora_Marca
        FOREIGN KEY (IdMarcaAsistencia) REFERENCES dbo.MarcaAsistencia(Id)
);
GO

-- ============================================================
-- TABLA: MovPlanilla
-- DESCRIPCIÓN: Libro de movimientos detallados por comprobante,
--              calculando saldos brutos acumulados secuenciales.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MovPlanilla')
CREATE TABLE dbo.MovPlanilla (
    Id               INT           NOT NULL IDENTITY(1,1),
    IdComprobante    INT           NOT NULL,
    IdTipoMovimiento INT           NOT NULL,
    Monto            DECIMAL(14,2) NOT NULL,
    SaldoBrutoAcum   DECIMAL(14,2) NOT NULL,
    CONSTRAINT PK_MovPlanilla PRIMARY KEY (Id),
    CONSTRAINT FK_MovPlan_Comprobante
        FOREIGN KEY (IdComprobante)    REFERENCES dbo.Comprobante(Id),
    CONSTRAINT FK_MovPlan_TipoMov
        FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento(Id)
);
GO

-- ============================================================
-- TABLA: BitacoraEvento
-- DESCRIPCIÓN: Registro de seguridad y auditoría de transacciones,
--              almacenando usuarios, IPs y marcas de tiempo.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BitacoraEvento')
CREATE TABLE dbo.BitacoraEvento (
    Id           INT          NOT NULL IDENTITY(1,1),
    IdTipoEvento INT          NOT NULL,
    IdUsuario    INT          NOT NULL,
    FechaHora    DATETIME     NOT NULL DEFAULT GETDATE(),
    IP           VARCHAR(45)  NOT NULL,
    Descripcion  VARCHAR(MAX) NULL,
    CONSTRAINT PK_BitacoraEvento PRIMARY KEY (Id),
    CONSTRAINT FK_Bitacora_TipoEvento
        FOREIGN KEY (IdTipoEvento) REFERENCES dbo.TipoEvento(Id),
    CONSTRAINT FK_Bitacora_Usuario
        FOREIGN KEY (IdUsuario)    REFERENCES dbo.Usuario(Id)
);
GO

-- ============================================================
-- TABLA: DBError
-- DESCRIPCIÓN: Captura excepciones controladas en bloques TRY/CATCH
--              dentro de los Stored Procedures para depuración.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DBError')
CREATE TABLE dbo.DBError (
    Id        INT          NOT NULL IDENTITY(1,1),
    Mensaje   VARCHAR(MAX) NOT NULL,
    Severidad INT          NOT NULL,
    Estado    INT          NOT NULL,
    FechaHora DATETIME     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_DBError PRIMARY KEY (Id)
);
GO


-- ============================================================
-- TABLA: MovimientoAsistencia
-- DESCRIPCIÓN: Es una tabla
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MovimientoAsistencia')
BEGIN
    CREATE TABLE dbo.MovimientoAsistencia (
        Id                INT           NOT NULL IDENTITY(1,1),
        IdMarcaAsistencia INT           NOT NULL,
        IdTipoMovimiento  INT           NOT NULL,
        CantidadHoras     DECIMAL(8,2)  NOT NULL,
        Monto             DECIMAL(14,2) NOT NULL,
        CONSTRAINT PK_MovimientoAsistencia PRIMARY KEY (Id),
        CONSTRAINT FK_MovAsis_Marca
            FOREIGN KEY (IdMarcaAsistencia) REFERENCES dbo.MarcaAsistencia(Id),
        CONSTRAINT FK_MovAsis_TipoMov
            FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento(Id)
    );
END
GO

-- ============================================================
-- TRIGGER
-- ============================================================

IF OBJECT_ID('dbo.trg_Empleado_DeduccionesObligatorias', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Empleado_DeduccionesObligatorias;
GO
IF OBJECT_ID('dbo.trg_asignar_deducciones_obligatorias', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_asignar_deducciones_obligatorias;
GO
CREATE TRIGGER dbo.trg_asignar_deducciones_obligatorias
ON dbo.Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.DeduccionEmpleado (IdEmpleado, IdTipoDeduccion, MontoFijo, FechaInicio, FechaFin)
    SELECT
        i.Id,
        td.Id,
        0,
        GETDATE(),
        NULL
    FROM inserted i
    CROSS JOIN dbo.TipoDeduccion td
    WHERE td.EsObligatoria = 1
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.DeduccionEmpleado de
          WHERE de.IdEmpleado = i.Id
            AND de.IdTipoDeduccion = td.Id
      );
END;
GO

-- ============================================================
-- ÍNDICES
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Empleado_Nombre' AND object_id = OBJECT_ID('dbo.Empleado'))
    CREATE INDEX IX_Empleado_Nombre ON dbo.Empleado (Nombre);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MarcaAsistencia_Empleado_Fecha' AND object_id = OBJECT_ID('dbo.MarcaAsistencia'))
    CREATE INDEX IX_MarcaAsistencia_Empleado_Fecha ON dbo.MarcaAsistencia (IdEmpleado, Fecha);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PlanillaSemanal_Semana' AND object_id = OBJECT_ID('dbo.PlanillaSemanal'))
    CREATE INDEX IX_PlanillaSemanal_Semana ON dbo.PlanillaSemanal (IdSemana);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PlanillaMensual_Mes' AND object_id = OBJECT_ID('dbo.PlanillaMensual'))
    CREATE INDEX IX_PlanillaMensual_Mes ON dbo.PlanillaMensual (IdMes);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BitacoraEvento_Usuario_FechaHora' AND object_id = OBJECT_ID('dbo.BitacoraEvento'))
    CREATE INDEX IX_BitacoraEvento_Usuario_FechaHora ON dbo.BitacoraEvento (IdUsuario, FechaHora DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DeduccionEmpleado_Vigencia' AND object_id = OBJECT_ID('dbo.DeduccionEmpleado'))
    CREATE INDEX IX_DeduccionEmpleado_Vigencia ON dbo.DeduccionEmpleado (IdEmpleado, FechaInicio, FechaFin);
GO














-- DATOS DE PRUEBA (SEED) PARA PROBAR EL LOGIN


USE PlanillaObrera;
GO

-- TipoEvento mínimo necesario para que la bitácora funcione en login
IF NOT EXISTS (SELECT 1 FROM dbo.TipoEvento WHERE Id = 1)
  INSERT INTO dbo.TipoEvento (Id, Nombre) VALUES (1, 'Login exitoso');
IF NOT EXISTS (SELECT 1 FROM dbo.TipoEvento WHERE Id = 2)
  INSERT INTO dbo.TipoEvento (Id, Nombre) VALUES (2, 'Login fallido');
IF NOT EXISTS (SELECT 1 FROM dbo.TipoEvento WHERE Id = 3)
  INSERT INTO dbo.TipoEvento (Id, Nombre) VALUES (3, 'Login deshabilitado');
IF NOT EXISTS (SELECT 1 FROM dbo.TipoEvento WHERE Id = 4)
  INSERT INTO dbo.TipoEvento (Id, Nombre) VALUES (4, 'Logout');
GO

-- Usuarios de prueba
-- Id es IDENTITY así que no se especifica, y la columna es PasswordHash no Password
IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Username = 'admin')
  INSERT INTO dbo.Usuario (Username, PasswordHash, Tipo)
  VALUES ('admin', 'admin123', 'administrador');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Username = 'obrero')
  INSERT INTO dbo.Usuario (Username, PasswordHash, Tipo)
  VALUES ('obrero', 'obrero123', 'empleado');
GO
