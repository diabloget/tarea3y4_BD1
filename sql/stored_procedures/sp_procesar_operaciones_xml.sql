USE PlanillaObrera;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_procesar_operaciones_xml', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_procesar_operaciones_xml;
GO

CREATE PROCEDURE dbo.sp_procesar_operaciones_xml
    @XmlData      XML,
    @OutRespuesta INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;
    SET @OutRespuesta = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. InsertarEmpleado
        --    Atributo en XML: ValorDocumentoIdentidad
        DECLARE @IdDoc         VARCHAR(50);
        DECLARE @Nom           VARCHAR(100);
        DECLARE @NomPuesto     VARCHAR(100);
        DECLARE @Cuenta        VARCHAR(100);
        DECLARE @FechaContrato DATE;
        DECLARE @RespIns       INT;

        DECLARE cur_emp CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
            Op.value('(@Nombre)[1]',                  'VARCHAR(100)'),
            Op.value('(@Puesto)[1]',                  'VARCHAR(100)'),
            Op.value('(@CuentaBancaria)[1]',           'VARCHAR(100)'),
            ISNULL(
                Op.value('(@FechaContratacion)[1]',   'DATE'),
                Op.value('(../@Fecha)[1]',            'DATE')
            )
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/InsertarEmpleado') AS T(Op);

        OPEN cur_emp;
        FETCH NEXT FROM cur_emp INTO @IdDoc, @Nom, @NomPuesto, @Cuenta, @FechaContrato;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.sp_insertar_empleado
                @ValorDocumento    = @IdDoc,
                @Nombre            = @Nom,
                @NombrePuesto      = @NomPuesto,
                @CuentaBancaria    = @Cuenta,
                @FechaContratacion = @FechaContrato,
                @OutRespuesta      = @RespIns OUTPUT;

            IF @RespIns = 50008
            BEGIN
                SET @OutRespuesta = 50008;
                CLOSE cur_emp; DEALLOCATE cur_emp;
                ROLLBACK TRANSACTION; RETURN;
            END
            FETCH NEXT FROM cur_emp INTO @IdDoc, @Nom, @NomPuesto, @Cuenta, @FechaContrato;
        END
        CLOSE cur_emp; DEALLOCATE cur_emp;

        -- 2. AsociaEmpleadoConDeduccion
        --    Inserta en DeduccionEmpleado con FechaInicio = FechaOperacion
        INSERT INTO dbo.DeduccionEmpleado (IdEmpleado, IdTipoDeduccion, MontoFijo, FechaInicio, FechaFin)
        SELECT
            E.Id,
            TD.Id,
            Op.value('(@MontoFijo)[1]', 'DECIMAL(12,2)'),
            Op.value('(../@Fecha)[1]',  'DATE'),
            NULL
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/AsociaEmpleadoConDeduccion') AS T(Op)
        INNER JOIN dbo.Empleado     E  ON E.ValorDocumento = Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')
        INNER JOIN dbo.TipoDeduccion TD ON TD.Nombre       = Op.value('(@TipoDeduccion)[1]',          'VARCHAR(100)')
        -- Evitar duplicar si ya existe una deducción vigente del mismo tipo para el empleado
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DeduccionEmpleado DE
            WHERE DE.IdEmpleado      = E.Id
              AND DE.IdTipoDeduccion = TD.Id
              AND DE.FechaFin        IS NULL
        );

        -- 3. DesasociaEmpleadoConDeduccion
        UPDATE DE
        SET    DE.FechaFin = Des.FechaOp
        FROM   dbo.DeduccionEmpleado DE
        INNER JOIN dbo.Empleado      E  ON E.Id  = DE.IdEmpleado
        INNER JOIN dbo.TipoDeduccion TD ON TD.Id = DE.IdTipoDeduccion
        INNER JOIN (
            SELECT
                Op2.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')  AS ValDoc,
                Op2.value('(@TipoDeduccion)[1]',           'VARCHAR(100)') AS NomDed,
                Op2.value('(../@Fecha)[1]',                'DATE')         AS FechaOp
            FROM @XmlData.nodes('/Operaciones/FechaOperacion/DesasociaEmpleadoConDeduccion') AS T2(Op2)
        ) AS Des ON Des.ValDoc  = E.ValorDocumento
                AND Des.NomDed  = TD.Nombre
                AND DE.FechaFin IS NULL;

        -- 4. AsignarJornada
        --    Crea Semana si no existe y luego HorarioJornada
        DECLARE @ValDoc2      VARCHAR(50);
        DECLARE @NomJornada   VARCHAR(100);
        DECLARE @InicioSemana DATE;
        DECLARE @IdEmpleado   INT;
        DECLARE @IdJornada    INT;
        DECLARE @IdSemana     INT;
        DECLARE @IdMes        INT;

        DECLARE cur_jornada CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
            Op.value('(@Jornada)[1]',                 'VARCHAR(100)'),
            Op.value('(@InicioSemana)[1]',            'DATE')
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/AsignarJornada') AS T(Op);

        OPEN cur_jornada;
        FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @IdEmpleado = Id FROM dbo.Empleado WHERE ValorDocumento = @ValDoc2;
            SELECT @IdJornada  = Id FROM dbo.TipoJornada WHERE Nombre = @NomJornada;

            IF @IdEmpleado IS NOT NULL AND @IdJornada IS NOT NULL
            BEGIN
                -- Buscar o crear el Mes que contiene InicioSemana
                SELECT @IdMes = Id FROM dbo.Mes
                WHERE @InicioSemana BETWEEN FechaInicio AND FechaFin;

                IF @IdMes IS NULL
                BEGIN
                    -- Crear mes: del primer día al último día del mes calendario
                    DECLARE @PrimerDia DATE = DATEFROMPARTS(YEAR(@InicioSemana), MONTH(@InicioSemana), 1);
                    DECLARE @UltimoDia DATE = EOMONTH(@InicioSemana);
                    DECLARE @NumJueves TINYINT = (
                        SELECT COUNT(*) FROM (
                            SELECT TOP 5
                                DATEADD(DAY, n.n, @PrimerDia) AS Dia
                            FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                        (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                        (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30)) n(n)
                            WHERE DATEADD(DAY, n.n, @PrimerDia) <= @UltimoDia
                              AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @PrimerDia)) = 'Thursday'
                        ) Jueves
                    );
                    INSERT INTO dbo.Mes (FechaInicio, FechaFin, NumJueves)
                    VALUES (@PrimerDia, @UltimoDia, @NumJueves);
                    SET @IdMes = SCOPE_IDENTITY();
                END

                -- Buscar o crear la Semana que empieza en InicioSemana
                SELECT @IdSemana = Id FROM dbo.Semana WHERE FechaInicio = @InicioSemana;
                IF @IdSemana IS NULL
                BEGIN
                    -- La semana va de InicioSemana (viernes) a InicioSemana+6 (jueves)
                    INSERT INTO dbo.Semana (IdMes, FechaInicio, FechaFin)
                    VALUES (@IdMes, @InicioSemana, DATEADD(DAY, 6, @InicioSemana));
                    SET @IdSemana = SCOPE_IDENTITY();
                END

                -- Insertar HorarioJornada si no existe
                IF NOT EXISTS (
                    SELECT 1 FROM dbo.HorarioJornada
                    WHERE IdEmpleado = @IdEmpleado AND IdSemana = @IdSemana
                )
                    INSERT INTO dbo.HorarioJornada (IdEmpleado, IdSemana, IdTipoJornada)
                    VALUES (@IdEmpleado, @IdSemana, @IdJornada);
            END

            FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
        END
        CLOSE cur_jornada; DEALLOCATE cur_jornada;

        -- 5. MarcaAsistencia
        --    Requiere que exista HorarioJornada para la semana correspondiente
        INSERT INTO dbo.MarcaAsistencia (IdEmpleado, IdHorarioJornada, Fecha, HoraEntrada, HoraSalida)
        SELECT
            E.Id,
            HJ.Id,
            CAST(Op.value('(@HoraEntrada)[1]', 'DATETIME') AS DATE),
            Op.value('(@HoraEntrada)[1]', 'DATETIME'),
            Op.value('(@HoraSalida)[1]',  'DATETIME')
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/MarcaAsistencia') AS T(Op)
        INNER JOIN dbo.Empleado E ON E.ValorDocumento = Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')
        INNER JOIN dbo.HorarioJornada HJ
            ON HJ.IdEmpleado = E.Id
            AND HJ.IdSemana = (
                SELECT TOP 1 S.Id FROM dbo.Semana S
                WHERE CAST(Op.value('(@HoraEntrada)[1]', 'DATETIME') AS DATE)
                      BETWEEN S.FechaInicio AND S.FechaFin
                ORDER BY S.FechaInicio DESC
            )
        -- Evitar duplicados por empleado+fecha
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.MarcaAsistencia MA
            WHERE MA.IdEmpleado = E.Id
              AND MA.Fecha = CAST(Op.value('(@HoraEntrada)[1]', 'DATETIME') AS DATE)
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
