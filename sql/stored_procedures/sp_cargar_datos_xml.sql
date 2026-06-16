USE PlanillaObrera;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_cargar_datos_xml', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_cargar_datos_xml;
GO

CREATE PROCEDURE dbo.sp_cargar_datos_xml
    @XmlData XML,
    @OutRespuesta INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    SET @OutRespuesta = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- TipoDocIdentidad
        IF NOT EXISTS (SELECT 1 FROM dbo.TipoDocIdentidad WHERE Id = 1)
            INSERT INTO dbo.TipoDocIdentidad (Id, Nombre) VALUES (1, 'Cédula');

        -- Departamento
        IF NOT EXISTS (SELECT 1 FROM dbo.Departamento WHERE Id = 1)
            INSERT INTO dbo.Departamento (Id, Nombre) VALUES (1, 'Producción y Operaciones');

        -- TipoEvento
        INSERT INTO dbo.TipoEvento (Id, Nombre)
        SELECT
            T.Item.value('@Id',     'INT'),
            T.Item.value('@Nombre', 'VARCHAR(100)')
        FROM @XmlData.nodes('/Datos/TiposEvento/TipoEvento') AS T(Item)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.TipoEvento
            WHERE Id = T.Item.value('@Id', 'INT')
        );

        -- Feriado
        INSERT INTO dbo.Feriado (Id, Nombre, Fecha)
        SELECT
            T.Item.value('@Id',     'INT'),
            T.Item.value('@Nombre', 'VARCHAR(150)'),
            T.Item.value('@Fecha',  'DATE')
        FROM @XmlData.nodes('/Datos/Feriados/Feriado') AS T(Item)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Feriado
            WHERE Id = T.Item.value('@Id', 'INT')
        );

        -- TipoMovimiento
        INSERT INTO dbo.TipoMovimiento (Id, Nombre, Accion)
        SELECT
            T.Item.value('@Id',     'INT'),
            T.Item.value('@Nombre', 'VARCHAR(100)'),
            CASE T.Item.value('@TipoAccion', 'VARCHAR(50)')
                WHEN 'Credito' THEN '+'
                WHEN 'Debito'  THEN '-'
                WHEN '+' THEN '+'
                WHEN '-' THEN '-'
                ELSE '+'          -- Fallback seguro para evitar fallos de constraint
            END
        FROM @XmlData.nodes('/Datos/TiposMovimientos/TipoMovimiento') AS T(Item)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoMovimiento WHERE Id = T.Item.value('@Id', 'INT'));

        -- ── TipoDeduccion ───────────────────────────────────────
        INSERT INTO dbo.TipoDeduccion (Id, Nombre, EsObligatoria, EsPorcentual, Valor, IdTipoMovimiento)
        SELECT
            T.Item.value('@Id',           'INT'),
            T.Item.value('@Nombre',       'VARCHAR(100)'),
            ISNULL(T.Item.value('@EsObligatoria','BIT'), 0),
            ISNULL(T.Item.value('@EsPorcentual', 'BIT'), 0),
            ISNULL(T.Item.value('@Valor',        'DECIMAL(10,4)'), 0), -- Por si NULL
            TM.Id
        FROM @XmlData.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS T(Item)
        INNER JOIN dbo.TipoMovimiento TM
            ON TM.Nombre = T.Item.value('@TipoMovimiento', 'VARCHAR(100)')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoDeduccion WHERE Id = T.Item.value('@Id', 'INT'));

        -- Puesto
        INSERT INTO dbo.Puesto (Nombre, SalarioXHora)
        SELECT
            T.Item.value('@Nombre',       'VARCHAR(100)'),
            T.Item.value('@SalarioxHora', 'MONEY')
        FROM @XmlData.nodes('/Datos/Puestos/Puesto') AS T(Item)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Puesto
            WHERE Nombre = T.Item.value('@Nombre', 'VARCHAR(100)')
        );

        -- TipoJornada
        INSERT INTO dbo.TipoJornada (Id, Nombre, HoraInicio, HoraFin)
        SELECT
            T.Item.value('@Id',         'INT'),
            T.Item.value('@Nombre',     'VARCHAR(100)'),
            T.Item.value('@HoraInicio', 'TIME'),
            T.Item.value('@HoraFin',    'TIME')
        FROM @XmlData.nodes('/Datos/TiposJornada/TipoJornada') AS T(Item)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.TipoJornada
            WHERE Id = T.Item.value('@Id', 'INT')
        );

        -- Usuarios
        INSERT INTO dbo.Usuario (Username, PasswordHash, Tipo)
        SELECT
            T.Item.value('@Nombre', 'VARCHAR(100)'),
            T.Item.value('@Pass',   'VARCHAR(256)'),
            CASE T.Item.value('@Id', 'INT')
                WHEN 1 THEN 'administrador'
                ELSE        'empleado'
            END
        FROM @XmlData.nodes('/Datos/Usuarios/usuario') AS T(Item)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Usuario
            WHERE Username = T.Item.value('@Nombre', 'VARCHAR(100)')
        );

        COMMIT TRANSACTION;
        SET @OutRespuesta = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
        VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());
        SET @OutRespuesta = 50008;
    END CATCH
END
GO
