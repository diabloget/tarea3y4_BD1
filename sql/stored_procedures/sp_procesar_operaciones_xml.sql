USE [PlanillaObrera]
GO
/****** Object:  StoredProcedure [dbo].[sp_procesar_operaciones_xml]    Script Date: 15/6/2026 12:09:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_procesar_operaciones_xml]
    @XmlData      XML,
    @OutRespuesta INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @OutRespuesta = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ============================================================
        -- 1. InsertarEmpleado
        -- ============================================================
        DECLARE @IdDoc VARCHAR(50), @Nom VARCHAR(100), @NomPuesto VARCHAR(100);
        DECLARE @Cuenta VARCHAR(100), @FechaContrato DATE, @RespIns INT;
        DECLARE @UName VARCHAR(64), @Pwd VARCHAR(128);

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

        -- ============================================================
        -- 2. AsociaEmpleadoConDeduccion
        -- ============================================================
        INSERT INTO dbo.DeduccionEmpleado (IdEmpleado, IdTipoDeduccion, MontoFijo, FechaInicio, FechaFin)
        SELECT
            E.Id, 
            TD.Id, 
            ISNULL(Op.value('(@MontoFijo)[1]', 'DECIMAL(12,2)'), 0), -- ISNULL salva de errores si es porcentual
            Op.value('(../@Fecha)[1]', 'DATE'), 
            NULL
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/AsociaEmpleadoConDeduccion') AS T(Op)
        INNER JOIN dbo.Empleado E ON E.ValorDocumento = Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')
        INNER JOIN dbo.TipoDeduccion TD ON TD.Nombre = Op.value('(@TipoDeduccion)[1]', 'VARCHAR(100)')
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DeduccionEmpleado DE
            WHERE DE.IdEmpleado = E.Id AND DE.IdTipoDeduccion = TD.Id AND DE.FechaFin IS NULL
        );

        -- ============================================================
        -- 3. DesasociaEmpleadoConDeduccion
        -- ============================================================
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

        -- ============================================================
        -- 4. AsignarJornada (CORREGIDO DE SINTAXIS Y ALCANCE)
        -- ============================================================
        DECLARE @ValDoc2 VARCHAR(50), @NomJornada VARCHAR(100), @InicioSemana DATE;
        DECLARE @IdEmpleado INT, @IdJornada INT, @IdSemana INT, @IdMes INT;
        DECLARE @PrimerDia DATE, @UltimoDia DATE, @NumJueves TINYINT;

        DECLARE cur_jornada CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
            Op.value('(@Jornada)[1]',                 'VARCHAR(100)'),
            ISNULL(Op.value('(@InicioSemana)[1]', 'DATE'), Op.value('(../@Fecha)[1]', 'DATE'))
        FROM @XmlData.nodes('/Operaciones/FechaOperacion/AsignarJornada') AS T(Op);

        OPEN cur_jornada;
        FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- LIMPIEZA DE VARIABLES (Evita que herede valores del ciclo anterior)
            SET @IdEmpleado = NULL; SET @IdJornada = NULL; SET @IdMes = NULL; SET @IdSemana = NULL;

            SELECT @IdEmpleado = Id FROM dbo.Empleado WHERE ValorDocumento = @ValDoc2;
            SELECT @IdJornada  = Id FROM dbo.TipoJornada WHERE Nombre = @NomJornada;

            IF @IdEmpleado IS NOT NULL AND @IdJornada IS NOT NULL AND @InicioSemana IS NOT NULL
            BEGIN
                -- A. GESTIÓN DEL MES
                SELECT @IdMes = Id FROM dbo.Mes WHERE @InicioSemana BETWEEN FechaInicio AND FechaFin;
                IF @IdMes IS NULL
                BEGIN
                    SET @PrimerDia = DATEFROMPARTS(YEAR(@InicioSemana), MONTH(@InicioSemana), 1);
                    SET @UltimoDia = EOMONTH(@InicioSemana);
                    SET @NumJueves = (
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

                -- B. GESTIÓN DE LA SEMANA (Ahora se ejecuta SIEMPRE)
                SELECT @IdSemana = Id FROM dbo.Semana WHERE FechaInicio = @InicioSemana;
                IF @IdSemana IS NULL
                BEGIN
                    INSERT INTO dbo.Semana (IdMes, FechaInicio, FechaFin) 
                    VALUES (@IdMes, @InicioSemana, DATEADD(DAY, 6, @InicioSemana));
                    SET @IdSemana = SCOPE_IDENTITY();
                END

                -- C. ASIGNAR HORARIO AL EMPLEADO
                IF NOT EXISTS (SELECT 1 FROM dbo.HorarioJornada WHERE IdEmpleado = @IdEmpleado AND IdSemana = @IdSemana)
                    INSERT INTO dbo.HorarioJornada (IdEmpleado, IdSemana, IdTipoJornada) VALUES (@IdEmpleado, @IdSemana, @IdJornada);
            END
            FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
        END
        CLOSE cur_jornada; DEALLOCATE cur_jornada;

        -- ============================================================
        -- 5. MarcaAsistencia (CORREGIDO: BUG DEL HORARIO INFINITO)
        -- ============================================================
        DECLARE @DocAsis VARCHAR(50), @HoraEntrada DATETIME, @HoraSalida DATETIME;
        DECLARE @IdEmpAsis INT, @SalarioXHora DECIMAL(14,2);
        DECLARE @IdHorarioJornada INT, @IdSemanaAsis INT, @HoraFinJornada TIME;
        DECLARE @FechaOp DATE, @FinJornadaReal DATETIME, @TotalHoras INT, @MinutosOrd INT;
        DECLARE @HorasOrd INT, @HorasExtras INT, @EsFeriado BIT, @EsDomingo BIT;
        DECLARE @CantOrdinaria DECIMAL(8,2), @CantExtraNormal DECIMAL(8,2), @CantExtraDoble DECIMAL(8,2);
        DECLARE @MontoOrdinario DECIMAL(14,2), @MontoExtra DECIMAL(14,2), @TotalGenerated DECIMAL(14,2);
        DECLARE @IdMarcaAsistencia INT;

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
            -- LIMPIEZA CRÍTICA: Esto mata el bug que te dejaba el ID en 4 pegado
            SET @IdEmpAsis = NULL; SET @SalarioXHora = NULL;
            SET @IdHorarioJornada = NULL; SET @IdSemanaAsis = NULL; SET @HoraFinJornada = NULL;

            SELECT @IdEmpAsis = E.Id, @SalarioXHora = P.SalarioXHora
            FROM dbo.Empleado E
            INNER JOIN dbo.Puesto P ON P.Id = E.IdPuesto
            WHERE E.ValorDocumento = @DocAsis;

            IF @IdEmpAsis IS NOT NULL
            BEGIN
                SET @FechaOp = CAST(@HoraEntrada AS DATE);
                
                -- Busca el horario específico para esa semana
                SELECT 
                    @IdHorarioJornada = HJ.Id,
                    @IdSemanaAsis = HJ.IdSemana,
                    @HoraFinJornada = TJ.HoraFin
                FROM dbo.HorarioJornada HJ
                INNER JOIN dbo.Semana S ON S.Id = HJ.IdSemana
                INNER JOIN dbo.TipoJornada TJ ON TJ.Id = HJ.IdTipoJornada
                WHERE HJ.IdEmpleado = @IdEmpAsis 
                  AND @FechaOp >= S.FechaInicio 
                  AND @FechaOp <= S.FechaFin;

                IF @IdHorarioJornada IS NOT NULL
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM dbo.MarcaAsistencia WHERE IdEmpleado = @IdEmpAsis AND Fecha = @FechaOp)
                    BEGIN
                        INSERT INTO dbo.MarcaAsistencia (IdEmpleado, IdHorarioJornada, Fecha, HoraEntrada, HoraSalida)
                        VALUES (@IdEmpAsis, @IdHorarioJornada, @FechaOp, @HoraEntrada, @HoraSalida);
                        SET @IdMarcaAsistencia = SCOPE_IDENTITY();

                        -- LÓGICA DE CÁLCULO DE HORAS
                        SET @FinJornadaReal = CAST(@FechaOp AS DATETIME) + CAST(@HoraFinJornada AS DATETIME);
                        IF CAST(@HoraFinJornada AS DATETIME) < CAST(CAST(@HoraEntrada AS TIME) AS DATETIME)
                            SET @FinJornadaReal = DATEADD(DAY, 1, @FinJornadaReal);

                        SET @TotalHoras = FLOOR(DATEDIFF(MINUTE, @HoraEntrada, @HoraSalida) / 60.0);
                        SET @MinutosOrd = DATEDIFF(MINUTE, @HoraEntrada, CASE WHEN @HoraSalida > @FinJornadaReal THEN @FinJornadaReal ELSE @HoraSalida END);
                        IF @MinutosOrd < 0 SET @MinutosOrd = 0;

                        SET @HorasOrd = FLOOR(@MinutosOrd / 60.0);
                        IF @HorasOrd > @TotalHoras SET @HorasOrd = @TotalHoras;

                        SET @HorasExtras = @TotalHoras - @HorasOrd;
                        IF @HorasExtras < 0 SET @HorasExtras = 0;

                        SET @EsFeriado = 0; SET @EsDomingo = 0;
                        IF EXISTS (SELECT 1 FROM dbo.Feriado WHERE Fecha = @FechaOp) SET @EsFeriado = 1;
                        IF (DATEPART(dw, @FechaOp) + @@DATEFIRST - 1) % 7 = 0 SET @EsDomingo = 1;

                        SET @CantOrdinaria = @HorasOrd;
                        SET @CantExtraNormal = 0; SET @CantExtraDoble = 0;
                        SET @MontoOrdinario = @CantOrdinaria * @SalarioXHora;
                        SET @MontoExtra = 0;

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

                        SET @TotalGenerated = @MontoOrdinario + @MontoExtra;

                        IF @CantOrdinaria > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 1, @CantOrdinaria, @MontoOrdinario);

                        IF @CantExtraNormal > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 2, @CantExtraNormal, @MontoExtra);

                        IF @CantExtraDoble > 0
                            INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                            VALUES (@IdMarcaAsistencia, 3, @CantExtraDoble, @MontoExtra);

                        IF NOT EXISTS (SELECT 1 FROM dbo.PlanillaSemanal WHERE IdEmpleado = @IdEmpAsis AND IdSemana = @IdSemanaAsis)
                        BEGIN
                            INSERT INTO dbo.PlanillaSemanal
                                (IdEmpleado, IdSemana, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtraNormal, HorasExtraDoble)
                            VALUES
                                (@IdEmpAsis, @IdSemanaAsis, @TotalGenerated, 0, 0, @CantOrdinaria, @CantExtraNormal, @CantExtraDoble);
                        END
                        ELSE
                        BEGIN
                            UPDATE dbo.PlanillaSemanal
                            SET SalarioBruto = SalarioBruto + @TotalGenerated,
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

        -- =========================================================
        -- 6. CALCULAR DEDUCCIONES Y SALARIO NETO FINALES
        -- =========================================================
        UPDATE PS
        SET PS.TotalDeducciones = 
            ISNULL((
                SELECT SUM(DE.MontoFijo)
                FROM dbo.DeduccionEmpleado DE
                INNER JOIN dbo.TipoDeduccion TD ON DE.IdTipoDeduccion = TD.Id
                INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                WHERE DE.IdEmpleado = PS.IdEmpleado
                  AND TD.EsPorcentual = 0
                  AND DE.FechaInicio <= S.FechaFin
                  AND (DE.FechaFin IS NULL OR DE.FechaFin >= S.FechaInicio)
            ), 0) 
            + 
            ISNULL((
                SELECT SUM(TD.Valor / 100.0) -- Se divide entre 100 asumiendo que 5% se guarda como 5.00
                FROM dbo.DeduccionEmpleado DE
                INNER JOIN dbo.TipoDeduccion TD ON DE.IdTipoDeduccion = TD.Id
                INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                WHERE DE.IdEmpleado = PS.IdEmpleado
                  AND TD.EsPorcentual = 1
                  AND DE.FechaInicio <= S.FechaFin
                  AND (DE.FechaFin IS NULL OR DE.FechaFin >= S.FechaInicio)
            ), 0) * PS.SalarioBruto
        FROM dbo.PlanillaSemanal PS;

        UPDATE dbo.PlanillaSemanal
        SET SalarioNeto = SalarioBruto - TotalDeducciones;

        COMMIT TRANSACTION;
        SET @OutRespuesta = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
        VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());
        SET @OutRespuesta = 50008;
    END CATCH
END;
