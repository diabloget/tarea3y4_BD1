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
        DECLARE @IdDoc         VARCHAR(50), @Nom VARCHAR(100), @NomPuesto VARCHAR(100);
        DECLARE @Cuenta        VARCHAR(100), @FechaContrato DATE, @RespIns INT;
        DECLARE @UName         VARCHAR(64), @Pwd VARCHAR(128);

        DECLARE cur_emp CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
            Op.value('(@Nombre)[1]',                  'VARCHAR(100)'),
            Op.value('(@Puesto)[1]',                  'VARCHAR(100)'),
            Op.value('(@CuentaBancaria)[1]',          'VARCHAR(100)'),
            ISNULL(Op.value('(@FechaContratacion)[1]', 'DATE'), Op.value('(../@Fecha)[1]', 'DATE')),
            Op.value('(@Username)[1]',                'VARCHAR(64)'),
            Op.value('(@Password)[1]',                'VARCHAR(128)')
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/InsertarEmpleado') AS T(Op);

        OPEN cur_emp;
        FETCH NEXT FROM cur_emp INTO @IdDoc, @Nom, @NomPuesto, @Cuenta, @FechaContrato, @UName, @Pwd;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.sp_insertar_empleado
                @ValorDocumento    = @IdDoc,
                @Nombre            = @Nom,
                @NombrePuesto      = @NomPuesto,
                @CuentaBancaria    = @Cuenta,
                @FechaContratacion = @FechaContrato,
                @Username          = @UName,
                @Password          = @Pwd,
                @OutRespuesta      = @RespIns OUTPUT;

            IF @RespIns IN (50004, 50005, 50008)
            BEGIN
                SET @OutRespuesta = @RespIns;
                CLOSE cur_emp; DEALLOCATE cur_emp;
                ROLLBACK TRANSACTION; RETURN;
            END
            FETCH NEXT FROM cur_emp INTO @IdDoc, @Nom, @NomPuesto, @Cuenta, @FechaContrato, @UName, @Pwd;
        END
        CLOSE cur_emp; DEALLOCATE cur_emp;

        -- 2. AsociaEmpleadoConDeduccion
        INSERT INTO dbo.DeduccionEmpleado (IdEmpleado, IdTipoDeduccion, MontoFijo, FechaInicio, FechaFin)
        SELECT
            E.Id, TD.Id, Op.value('(@MontoFijo)[1]', 'DECIMAL(12,2)'),
            Op.value('(../@Fecha)[1]', 'DATE'), NULL
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/AsociaEmpleadoConDeduccion') AS T(Op)
        INNER JOIN dbo.Empleado E ON E.ValorDocumento = Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')
        INNER JOIN dbo.TipoDeduccion TD ON TD.Nombre = Op.value('(@TipoDeduccion)[1]', 'VARCHAR(100)')
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DeduccionEmpleado DE
            WHERE DE.IdEmpleado = E.Id AND DE.IdTipoDeduccion = TD.Id AND DE.FechaFin IS NULL
        );

        -- 3. DesasociaEmpleadoConDeduccion
        UPDATE DE
        SET DE.FechaFin = Des.FechaOp
        FROM dbo.DeduccionEmpleado DE
        INNER JOIN dbo.Empleado E ON E.Id  = DE.IdEmpleado
        INNER JOIN dbo.TipoDeduccion TD ON TD.Id = DE.IdTipoDeduccion
        INNER JOIN (
            SELECT
                Op2.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)') AS ValDoc,
                Op2.value('(@TipoDeduccion)[1]', 'VARCHAR(100)') AS NomDed,
                Op2.value('(../@Fecha)[1]', 'DATE') AS FechaOp
            FROM @XmlData.nodes('/Operaciones/FechaOperacion/DesasociaEmpleadoConDeduccion') AS T2(Op2)
        ) AS Des ON Des.ValDoc = E.ValorDocumento AND Des.NomDed = TD.Nombre AND DE.FechaFin IS NULL;

        -- 4. AsignarJornada
        DECLARE @ValDoc2 VARCHAR(50), @NomJornada VARCHAR(100), @InicioSemana DATE;
        DECLARE @IdEmpleado INT, @IdJornada INT, @IdSemana INT, @IdMes INT;

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
                SELECT @IdMes = Id FROM dbo.Mes WHERE @InicioSemana BETWEEN FechaInicio AND FechaFin;
                IF @IdMes IS NULL
                BEGIN
                    DECLARE @PrimerDia DATE = DATEFROMPARTS(YEAR(@InicioSemana), MONTH(@InicioSemana), 1);
                    DECLARE @UltimoDia DATE = EOMONTH(@InicioSemana);
                    DECLARE @NumJueves TINYINT = (
                        SELECT COUNT(*) FROM (
                            SELECT TOP 5 DATEADD(DAY, n.n, @PrimerDia) AS Dia
                            FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                        (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                        (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30)) n(n)
                            WHERE DATEADD(DAY, n.n, @PrimerDia) <= @UltimoDia AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @PrimerDia)) = 'Thursday'
                        ) Jueves
                    );
                    INSERT INTO dbo.Mes (FechaInicio, FechaFin, NumJueves) VALUES (@PrimerDia, @UltimoDia, @NumJueves);
                    SET @IdMes = SCOPE_IDENTITY();
                END

                SELECT @IdSemana = Id FROM dbo.Semana WHERE FechaInicio = @InicioSemana;
                IF @IdSemana IS NULL
                BEGIN
                    INSERT INTO dbo.Semana (IdMes, FechaInicio, FechaFin) VALUES (@IdMes, @InicioSemana, DATEADD(DAY, 6, @InicioSemana));
                    SET @IdSemana = SCOPE_IDENTITY();
                END

                IF NOT EXISTS (SELECT 1 FROM dbo.HorarioJornada WHERE IdEmpleado = @IdEmpleado AND IdSemana = @IdSemana)
                    INSERT INTO dbo.HorarioJornada (IdEmpleado, IdSemana, IdTipoJornada) VALUES (@IdEmpleado, @IdSemana, @IdJornada);
            END
            FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
        END
        CLOSE cur_jornada; DEALLOCATE cur_jornada;


        -- 5. MarcaAsistencia
        DECLARE @DocAsis VARCHAR(50), @HoraEntrada DATETIME, @HoraSalida DATETIME;

        DECLARE cur_asis CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
            Op.value('(@HoraEntrada)[1]', 'DATETIME'),
            Op.value('(@HoraSalida)[1]',  'DATETIME')
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/MarcaAsistencia') AS T(Op);

        OPEN cur_asis;
        FETCH NEXT FROM cur_asis INTO @DocAsis, @HoraEntrada, @HoraSalida;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @IdEmpAsis INT, @SalarioXHora DECIMAL(14,2);
            SELECT @IdEmpAsis = E.Id, @SalarioXHora = P.SalarioXHora
            FROM dbo.Empleado E
            INNER JOIN dbo.Puesto P ON P.Id = E.IdPuesto
            WHERE E.ValorDocumento = @DocAsis;

            IF @IdEmpAsis IS NOT NULL
            BEGIN
                DECLARE @FechaOp DATE = CAST(@HoraEntrada AS DATE);

                -- Buscar el horario jornada de la semana correspondiente a la marca
                DECLARE @IdHorarioJornada INT, @IdSemanaAsis INT, @HoraFinJornada TIME;
                SELECT TOP 1
                    @IdHorarioJornada = HJ.Id,
                    @IdSemanaAsis = S.Id,
                    @HoraFinJornada = TJ.HoraFin
                FROM dbo.Semana S
                INNER JOIN dbo.HorarioJornada HJ ON HJ.IdSemana = S.Id
                INNER JOIN dbo.TipoJornada TJ ON TJ.Id = HJ.IdTipoJornada
                WHERE HJ.IdEmpleado = @IdEmpAsis AND @FechaOp BETWEEN S.FechaInicio AND S.FechaFin
                ORDER BY S.FechaInicio DESC;

                IF @IdHorarioJornada IS NOT NULL
                BEGIN
                    -- Validar que la marca no esté duplicada por empleado y fecha
                    IF NOT EXISTS (SELECT 1 FROM dbo.MarcaAsistencia WHERE IdEmpleado = @IdEmpAsis AND Fecha = @FechaOp)
                    BEGIN
                        -- Insertar la marca base
                        INSERT INTO dbo.MarcaAsistencia (IdEmpleado, IdHorarioJornada, Fecha, HoraEntrada, HoraSalida)
                        VALUES (@IdEmpAsis, @IdHorarioJornada, @FechaOp, @HoraEntrada, @HoraSalida);
                        DECLARE @IdMarcaAsistencia INT = SCOPE_IDENTITY();

                        -- LÓGICA DE CÁLCULO DE HORAS
                        -- 1. Determinar hora real de finalización (para nocturnas traslapadas)
                        DECLARE @FinJornadaReal DATETIME = CAST(@FechaOp AS DATETIME) + CAST(@HoraFinJornada AS DATETIME);
                        IF CAST(@HoraFinJornada AS DATETIME) < CAST(CAST(@HoraEntrada AS TIME) AS DATETIME)
                        BEGIN
                            SET @FinJornadaReal = DATEADD(DAY, 1, @FinJornadaReal);
                        END

                        -- 2. Calcular duraciones
                        DECLARE @TotalHoras INT = FLOOR(DATEDIFF(MINUTE, @HoraEntrada, @HoraSalida) / 60.0);

                        -- Las ordinarias se limitan hasta la HoraFin definida en la jornada
                        DECLARE @MinutosOrd INT = DATEDIFF(MINUTE, @HoraEntrada, CASE WHEN @HoraSalida > @FinJornadaReal THEN @FinJornadaReal ELSE @HoraSalida END);
                        IF @MinutosOrd < 0 SET @MinutosOrd = 0;

                        DECLARE @HorasOrd INT = FLOOR(@MinutosOrd / 60.0);
                        IF @HorasOrd > @TotalHoras SET @HorasOrd = @TotalHoras;

                        DECLARE @HorasExtras INT = @TotalHoras - @HorasOrd;
                        IF @HorasExtras < 0 SET @HorasExtras = 0;

                        -- 3. Identificar festivos y domingos (Método robusto sin depender de @@DATEFIRST)
                        DECLARE @EsFeriado BIT = 0, @EsDomingo BIT = 0;
                        IF EXISTS (SELECT 1 FROM dbo.Feriado WHERE Fecha = @FechaOp) SET @EsFeriado = 1;
                        IF (DATEPART(dw, @FechaOp) + @@DATEFIRST - 1) % 7 = 0 SET @EsDomingo = 1;

                        -- 4. Calcular Montos y Cantidades
                        DECLARE @CantOrdinaria DECIMAL(8,2) = @HorasOrd;
                        DECLARE @CantExtraNormal DECIMAL(8,2) = 0;
                        DECLARE @CantExtraDoble DECIMAL(8,2) = 0;

                        DECLARE @MontoOrdinario DECIMAL(14,2) = @CantOrdinaria * @SalarioXHora;
                        DECLARE @MontoExtra DECIMAL(14,2) = 0;

                        IF @HorasExtras > 0
                        BEGIN
                            IF @EsDomingo = 1 OR @EsFeriado = 1
                            BEGIN
                                SET @CantExtraDoble = @HorasExtras;
                                SET @MontoExtra = @CantExtraDoble * (@SalarioXHora * 2.0);
                            END
                            ELSE
                            BEGIN
                                SET @CantExtraNormal = @HorasExtras;
                                SET @MontoExtra = @CantExtraNormal * (@SalarioXHora * 1.5);
                            END
                        END

                        DECLARE @TotalGenerado DECIMAL(14,2) = @MontoOrdinario + @MontoExtra;

                        -- 5. Generar Desglose en MovimientoAsistencia (Id=1 Ordinaria, Id=2 Extra Norm, Id=3 Extra Doble)
                        IF @CantOrdinaria > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 1, @CantOrdinaria, @MontoOrdinario);

                        IF @CantExtraNormal > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 2, @CantExtraNormal, @MontoExtra);

                        IF @CantExtraDoble > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 3, @CantExtraDoble, @MontoExtra);

                        -- 6. Acumular en PlanillaSemanal (UPSERT)
                        IF NOT EXISTS (SELECT 1 FROM dbo.PlanillaSemanal WHERE IdEmpleado = @IdEmpAsis AND IdSemana = @IdSemanaAsis)
                        BEGIN
                            INSERT INTO dbo.PlanillaSemanal
                                (IdEmpleado, IdSemana, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtraNormal, HorasExtraDoble)
                            VALUES
                                (@IdEmpAsis, @IdSemanaAsis, @TotalGenerado, 0, 0, @CantOrdinaria, @CantExtraNormal, @CantExtraDoble);
                        END
                        ELSE
                        BEGIN
                            UPDATE dbo.PlanillaSemanal
                            SET SalarioBruto = SalarioBruto + @TotalGenerado,
                                HorasOrdinarias = HorasOrdinarias + @CantOrdinaria,
                                HorasExtraNormal = HorasExtraNormal + @CantExtraNormal,
                                HorasExtraDoble = HorasExtraDoble + @CantExtraDoble
                            WHERE IdEmpleado = @IdEmpAsis AND IdSemana = @IdSemanaAsis;
                        END
                    END
                END
            END
            FETCH NEXT FROM cur_asis INTO @DocAsis, @HoraEntrada, @HoraSalida;
        END
        CLOSE cur_asis; DEALLOCATE cur_asis;

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
