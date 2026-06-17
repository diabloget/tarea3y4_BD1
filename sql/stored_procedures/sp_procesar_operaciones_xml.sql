USE [PlanillaObrera]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_procesar_operaciones_xml]
    @XmlData      XML,
    @OutRespuesta INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @OutRespuesta = 0;

    DECLARE @FechaProceso DATE, @DocProceso VARCHAR(50);
    DECLARE @RespIns INT, @RespDel INT, @RespDesDed INT;
    DECLARE @IdDoc VARCHAR(50), @Nom VARCHAR(100), @NomPuesto VARCHAR(100);
    DECLARE @Cuenta VARCHAR(100), @FechaContrato DATE, @UName VARCHAR(64), @Pwd VARCHAR(128);
    DECLARE @IdDocEliminar VARCHAR(50);
    DECLARE @ValDocDesDed VARCHAR(50), @NomDedDes VARCHAR(100);
    DECLARE @ValDoc2 VARCHAR(50), @NomJornada VARCHAR(100), @InicioSemana DATE;
    DECLARE @IdEmpleado INT, @IdEmpleadoNuevo INT, @IdJornada INT, @IdSemana INT, @IdMes INT;
    DECLARE @PrimerDia DATE, @UltimoDia DATE, @NumJueves TINYINT;
    DECLARE @ViernesSiguiente DATE, @FechaFinNuevoMes DATE, @IdMesNuevo INT;
    DECLARE @IdEmpleadoCierre INT, @IdMesCierre INT, @IdPlanillaMensual INT;
    DECLARE @DocAsis VARCHAR(50), @HoraEntrada DATETIME, @HoraSalida DATETIME;
    DECLARE @IdEmpAsis INT, @SalarioXHora DECIMAL(14,2);
    DECLARE @IdHorarioJornada INT, @IdSemanaAsis INT, @HoraFinJornada TIME;
    DECLARE @FechaOp DATE, @FinJornadaReal DATETIME, @TotalHoras INT, @MinutosOrd INT;
    DECLARE @HorasOrd INT, @HorasExtras INT, @EsFeriado BIT, @EsDomingo BIT;
    DECLARE @CantOrdinaria DECIMAL(8,2), @CantExtraNormal DECIMAL(8,2), @CantExtraDoble DECIMAL(8,2);
    DECLARE @MontoOrdinario DECIMAL(14,2), @MontoExtra DECIMAL(14,2), @TotalGenerated DECIMAL(14,2);
    DECLARE @IdMarcaAsistencia INT;

    CREATE TABLE #InsertarEmpleado (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Puesto VARCHAR(100) NOT NULL,
        CuentaBancaria VARCHAR(100) NULL,
        FechaContratacion DATE NOT NULL,
        Username VARCHAR(64) NULL,
        Password VARCHAR(128) NULL
    );

    CREATE TABLE #EliminarEmpleado (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL
    );

    CREATE TABLE #AsociaDeduccion (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL,
        TipoDeduccion VARCHAR(100) NOT NULL,
        MontoFijo DECIMAL(12,2) NOT NULL
    );

    CREATE TABLE #DesasociaDeduccion (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL,
        TipoDeduccion VARCHAR(100) NOT NULL
    );

    CREATE TABLE #MarcaAsistencia (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL,
        HoraEntrada DATETIME NOT NULL,
        HoraSalida DATETIME NOT NULL
    );

    CREATE TABLE #AsignarJornada (
        Fecha DATE NOT NULL,
        ValorDocumento VARCHAR(50) NOT NULL,
        Jornada VARCHAR(100) NOT NULL,
        InicioSemana DATE NOT NULL
    );

    INSERT INTO #InsertarEmpleado (Fecha, ValorDocumento, Nombre, Puesto, CuentaBancaria, FechaContratacion, Username, Password)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
        Op.value('(@Nombre)[1]',                  'VARCHAR(100)'),
        Op.value('(@Puesto)[1]',                  'VARCHAR(100)'),
        Op.value('(@CuentaBancaria)[1]',          'VARCHAR(100)'),
        ISNULL(Op.value('(@FechaContratacion)[1]', 'DATE'), F.FechaOperacion.value('(@Fecha)[1]', 'DATE')),
        Op.value('(@Username)[1]',                'VARCHAR(64)'),
        Op.value('(@Password)[1]',                'VARCHAR(128)')
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('InsertarEmpleado') AS T(Op);

    INSERT INTO #EliminarEmpleado (Fecha, ValorDocumento)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)')
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('EliminarEmpleado') AS T(Op);

    INSERT INTO #AsociaDeduccion (Fecha, ValorDocumento, TipoDeduccion, MontoFijo)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
        Op.value('(@TipoDeduccion)[1]', 'VARCHAR(100)'),
        ISNULL(Op.value('(@MontoFijo)[1]', 'DECIMAL(12,2)'), 0)
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('AsociaEmpleadoConDeduccion') AS T(Op);

    INSERT INTO #DesasociaDeduccion (Fecha, ValorDocumento, TipoDeduccion)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
        Op.value('(@TipoDeduccion)[1]', 'VARCHAR(100)')
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('DesasociaEmpleadoConDeduccion') AS T(Op);

    INSERT INTO #MarcaAsistencia (Fecha, ValorDocumento, HoraEntrada, HoraSalida)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
        Op.value('(@HoraEntrada)[1]', 'DATETIME'),
        Op.value('(@HoraSalida)[1]',  'DATETIME')
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('MarcaAsistencia') AS T(Op);

    INSERT INTO #AsignarJornada (Fecha, ValorDocumento, Jornada, InicioSemana)
    SELECT
        F.FechaOperacion.value('(@Fecha)[1]', 'DATE'),
        Op.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(50)'),
        Op.value('(@Jornada)[1]',                 'VARCHAR(100)'),
        ISNULL(Op.value('(@InicioSemana)[1]', 'DATE'), F.FechaOperacion.value('(@Fecha)[1]', 'DATE'))
    FROM @XmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('AsignarJornada') AS T(Op);

    DECLARE cur_operacion CURSOR LOCAL FAST_FORWARD FOR
    SELECT Fecha, ValorDocumento
    FROM (
        SELECT Fecha, ValorDocumento FROM #InsertarEmpleado
        UNION
        SELECT Fecha, ValorDocumento FROM #EliminarEmpleado
        UNION
        SELECT Fecha, ValorDocumento FROM #AsociaDeduccion
        UNION
        SELECT Fecha, ValorDocumento FROM #DesasociaDeduccion
        UNION
        SELECT Fecha, ValorDocumento FROM #MarcaAsistencia
        UNION
        SELECT Fecha, ValorDocumento FROM #AsignarJornada
    ) Operaciones
    WHERE Fecha IS NOT NULL
      AND NULLIF(ValorDocumento, '') IS NOT NULL
    GROUP BY Fecha, ValorDocumento
    ORDER BY Fecha, ValorDocumento;

    OPEN cur_operacion;
    FETCH NEXT FROM cur_operacion INTO @FechaProceso, @DocProceso;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- InsertarEmpleado del empleado en la fecha actual.
            DECLARE cur_emp CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                ValorDocumento,
                Nombre,
                Puesto,
                CuentaBancaria,
                FechaContratacion,
                Username,
                Password
            FROM #InsertarEmpleado
            WHERE Fecha = @FechaProceso
              AND ValorDocumento = @DocProceso;

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
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    CLOSE cur_operacion; DEALLOCATE cur_operacion;
                    RETURN;
                END

                IF DATENAME(WEEKDAY, @FechaProceso) = 'Thursday'
                BEGIN
                    SET @ViernesSiguiente = DATEADD(DAY, 1, @FechaProceso);
                    SET @IdEmpleadoNuevo = NULL; SET @IdMesNuevo = NULL; SET @IdSemana = NULL;

                    SELECT @IdEmpleadoNuevo = Id
                    FROM dbo.Empleado
                    WHERE ValorDocumento = @IdDoc
                      AND Activo = 1;

                    IF @IdEmpleadoNuevo IS NOT NULL
                    BEGIN
                        SELECT TOP 1 @IdMesNuevo = Id
                        FROM dbo.Mes
                        WHERE @ViernesSiguiente BETWEEN FechaInicio AND FechaFin
                        ORDER BY
                            CASE WHEN FechaInicio = @ViernesSiguiente THEN 0 ELSE 1 END,
                            FechaInicio DESC;

                        IF @IdMesNuevo IS NULL
                        BEGIN
                            SET @FechaFinNuevoMes = (
                                SELECT MAX(Dia)
                                FROM (
                                    SELECT DATEADD(DAY, n.n, @ViernesSiguiente) AS Dia
                                    FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                                (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                                (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                                (31),(32),(33),(34),(35),(36),(37)) n(n)
                                    WHERE DATEADD(DAY, n.n, @ViernesSiguiente) <= EOMONTH(@ViernesSiguiente)
                                      AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @ViernesSiguiente)) = 'Thursday'
                                ) JuevesNuevoMes
                            );

                            IF @FechaFinNuevoMes IS NULL
                                SET @FechaFinNuevoMes = DATEADD(DAY, 6, @ViernesSiguiente);

                            SET @NumJueves = (
                                SELECT COUNT(*)
                                FROM (
                                    SELECT DATEADD(DAY, n.n, @ViernesSiguiente) AS Dia
                                    FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                                (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                                (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                                (31),(32),(33),(34),(35),(36),(37)) n(n)
                                    WHERE DATEADD(DAY, n.n, @ViernesSiguiente) <= @FechaFinNuevoMes
                                      AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @ViernesSiguiente)) = 'Thursday'
                                ) JuevesNuevoMes
                            );

                            IF @NumJueves = 0 SET @NumJueves = 1;

                            INSERT INTO dbo.Mes (FechaInicio, FechaFin, NumJueves)
                            VALUES (@ViernesSiguiente, @FechaFinNuevoMes, @NumJueves);
                            SET @IdMesNuevo = SCOPE_IDENTITY();
                        END

                        SELECT @IdSemana = Id
                        FROM dbo.Semana
                        WHERE FechaInicio = @ViernesSiguiente;

                        IF @IdSemana IS NULL
                        BEGIN
                            INSERT INTO dbo.Semana (IdMes, FechaInicio, FechaFin)
                            VALUES (@IdMesNuevo, @ViernesSiguiente, DATEADD(DAY, 6, @ViernesSiguiente));
                            SET @IdSemana = SCOPE_IDENTITY();
                        END

                        IF NOT EXISTS (
                            SELECT 1
                            FROM dbo.PlanillaSemanal
                            WHERE IdEmpleado = @IdEmpleadoNuevo
                              AND IdSemana = @IdSemana
                        )
                        BEGIN
                            INSERT INTO dbo.PlanillaSemanal
                                (IdEmpleado, IdSemana, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtraNormal, HorasExtraDoble)
                            VALUES
                                (@IdEmpleadoNuevo, @IdSemana, 0, 0, 0, 0, 0, 0);
                        END

                        IF DATEPART(DAY, @ViernesSiguiente) <= 7
                           AND NOT EXISTS (
                               SELECT 1
                               FROM dbo.PlanillaMensual
                               WHERE IdEmpleado = @IdEmpleadoNuevo
                                 AND IdMes = @IdMesNuevo
                           )
                        BEGIN
                            INSERT INTO dbo.PlanillaMensual (IdEmpleado, IdMes, SalarioBruto, TotalDeducciones, SalarioNeto)
                            VALUES (@IdEmpleadoNuevo, @IdMesNuevo, 0, 0, 0);
                        END
                    END
                END

                FETCH NEXT FROM cur_emp INTO @IdDoc, @Nom, @NomPuesto, @Cuenta, @FechaContrato, @UName, @Pwd;
            END
            CLOSE cur_emp; DEALLOCATE cur_emp;

            -- EliminarEmpleado del empleado en la fecha actual.
            DECLARE cur_emp_del CURSOR LOCAL FAST_FORWARD FOR
            SELECT ValorDocumento
            FROM #EliminarEmpleado
            WHERE Fecha = @FechaProceso
              AND ValorDocumento = @DocProceso;

            OPEN cur_emp_del;
            FETCH NEXT FROM cur_emp_del INTO @IdDocEliminar;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.sp_eliminar_empleado
                    @ValorDocumento = @IdDocEliminar,
                    @OutRespuesta   = @RespDel OUTPUT;

                IF @RespDel IN (50001, 50008)
                BEGIN
                    SET @OutRespuesta = @RespDel;
                    CLOSE cur_emp_del; DEALLOCATE cur_emp_del;
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    CLOSE cur_operacion; DEALLOCATE cur_operacion;
                    RETURN;
                END

                FETCH NEXT FROM cur_emp_del INTO @IdDocEliminar;
            END
            CLOSE cur_emp_del; DEALLOCATE cur_emp_del;

            -- AsociaEmpleadoConDeduccion del empleado en la fecha actual.
            INSERT INTO dbo.DeduccionEmpleado (IdEmpleado, IdTipoDeduccion, MontoFijo, FechaInicio, FechaFin)
            SELECT
                E.Id,
                TD.Id,
                AD.MontoFijo,
                @FechaProceso,
                NULL
            FROM #AsociaDeduccion AD
            INNER JOIN dbo.Empleado E
                ON E.ValorDocumento = AD.ValorDocumento
               AND E.Activo = 1
            INNER JOIN dbo.TipoDeduccion TD
                ON TD.Nombre = AD.TipoDeduccion
            WHERE AD.Fecha = @FechaProceso
              AND AD.ValorDocumento = @DocProceso
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.DeduccionEmpleado DE
                  WHERE DE.IdEmpleado = E.Id
                    AND DE.IdTipoDeduccion = TD.Id
                    AND DE.FechaFin IS NULL
              );

            -- DesasociaEmpleadoConDeduccion del empleado en la fecha actual.
            DECLARE cur_des_ded CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                ValorDocumento,
                TipoDeduccion
            FROM #DesasociaDeduccion
            WHERE Fecha = @FechaProceso
              AND ValorDocumento = @DocProceso;

            OPEN cur_des_ded;
            FETCH NEXT FROM cur_des_ded INTO @ValDocDesDed, @NomDedDes;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.sp_desasociar_deduccion
                    @ValorDocumento  = @ValDocDesDed,
                    @NombreDeduccion = @NomDedDes,
                    @OutRespuesta    = @RespDesDed OUTPUT;

                IF @RespDesDed IN (50001, 50008)
                BEGIN
                    SET @OutRespuesta = @RespDesDed;
                    CLOSE cur_des_ded; DEALLOCATE cur_des_ded;
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    CLOSE cur_operacion; DEALLOCATE cur_operacion;
                    RETURN;
                END

                FETCH NEXT FROM cur_des_ded INTO @ValDocDesDed, @NomDedDes;
            END
            CLOSE cur_des_ded; DEALLOCATE cur_des_ded;

            -- AsignarJornada del empleado en la fecha actual. Empleados inactivos se ignoran.
            DECLARE cur_jornada CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                ValorDocumento,
                Jornada,
                InicioSemana
            FROM #AsignarJornada
            WHERE Fecha = @FechaProceso
              AND ValorDocumento = @DocProceso;

            OPEN cur_jornada;
            FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @IdEmpleado = NULL; SET @IdJornada = NULL; SET @IdMes = NULL; SET @IdSemana = NULL;

                SELECT @IdEmpleado = Id
                FROM dbo.Empleado
                WHERE ValorDocumento = @ValDoc2
                  AND Activo = 1;

                SELECT @IdJornada = Id FROM dbo.TipoJornada WHERE Nombre = @NomJornada;

                IF @IdEmpleado IS NOT NULL AND @IdJornada IS NOT NULL AND @InicioSemana IS NOT NULL
                BEGIN
                    SELECT TOP 1 @IdMes = Id
                    FROM dbo.Mes
                    WHERE @InicioSemana BETWEEN FechaInicio AND FechaFin
                    ORDER BY
                        CASE WHEN FechaInicio = @InicioSemana THEN 0 ELSE 1 END,
                        FechaInicio DESC;
                    IF @IdMes IS NULL
                    BEGIN
                        SET @PrimerDia = @InicioSemana;
                        SET @UltimoDia = (
                            SELECT MAX(Dia)
                            FROM (
                                SELECT DATEADD(DAY, n.n, @PrimerDia) AS Dia
                                FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                            (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                            (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                            (31),(32),(33),(34),(35),(36),(37)) n(n)
                                WHERE DATEADD(DAY, n.n, @PrimerDia) <= EOMONTH(@PrimerDia)
                                  AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @PrimerDia)) = 'Thursday'
                            ) Jueves
                        );
                        IF @UltimoDia IS NULL
                            SET @UltimoDia = DATEADD(DAY, 6, @PrimerDia);

                        SET @NumJueves = (
                            SELECT COUNT(*)
                            FROM (
                                SELECT DATEADD(DAY, n.n, @PrimerDia) AS Dia
                                FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                            (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                            (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                            (31),(32),(33),(34),(35),(36),(37)) n(n)
                                WHERE DATEADD(DAY, n.n, @PrimerDia) <= @UltimoDia
                                  AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @PrimerDia)) = 'Thursday'
                            ) Jueves
                        );
                        INSERT INTO dbo.Mes (FechaInicio, FechaFin, NumJueves) VALUES (@PrimerDia, @UltimoDia, @NumJueves);
                        SET @IdMes = SCOPE_IDENTITY();
                    END

                    SELECT @IdSemana = Id FROM dbo.Semana WHERE FechaInicio = @InicioSemana;
                    IF @IdSemana IS NULL
                    BEGIN
                        INSERT INTO dbo.Semana (IdMes, FechaInicio, FechaFin)
                        VALUES (@IdMes, @InicioSemana, DATEADD(DAY, 6, @InicioSemana));
                        SET @IdSemana = SCOPE_IDENTITY();
                    END

                    IF NOT EXISTS (SELECT 1 FROM dbo.HorarioJornada WHERE IdEmpleado = @IdEmpleado AND IdSemana = @IdSemana)
                        INSERT INTO dbo.HorarioJornada (IdEmpleado, IdSemana, IdTipoJornada)
                        VALUES (@IdEmpleado, @IdSemana, @IdJornada);
                END

                FETCH NEXT FROM cur_jornada INTO @ValDoc2, @NomJornada, @InicioSemana;
            END
            CLOSE cur_jornada; DEALLOCATE cur_jornada;

            -- MarcaAsistencia, movimientos y acumulado semanal del empleado en la fecha actual.
            DECLARE cur_asis CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                ValorDocumento,
                HoraEntrada,
                HoraSalida
            FROM #MarcaAsistencia
            WHERE Fecha = @FechaProceso
              AND ValorDocumento = @DocProceso;

            OPEN cur_asis;
            FETCH NEXT FROM cur_asis INTO @DocAsis, @HoraEntrada, @HoraSalida;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @IdEmpAsis = NULL; SET @SalarioXHora = NULL;
                SET @IdHorarioJornada = NULL; SET @IdSemanaAsis = NULL; SET @HoraFinJornada = NULL;

                SELECT @IdEmpAsis = E.Id, @SalarioXHora = P.SalarioXHora
                FROM dbo.Empleado E
                INNER JOIN dbo.Puesto P ON P.Id = E.IdPuesto
                WHERE E.ValorDocumento = @DocAsis
                  AND E.Activo = 1;

                IF @IdEmpAsis IS NOT NULL
                BEGIN
                    SET @FechaOp = CAST(@HoraEntrada AS DATE);

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
                                WHERE IdEmpleado = @IdEmpAsis
                                  AND IdSemana = @IdSemanaAsis;
                            END
                        END
                    END
                END

                FETCH NEXT FROM cur_asis INTO @DocAsis, @HoraEntrada, @HoraSalida;
            END
            CLOSE cur_asis; DEALLOCATE cur_asis;

            -- Cierre de jueves: deducciones y salario neto del empleado/semana actual.
            IF DATENAME(WEEKDAY, @FechaProceso) = 'Thursday'
            BEGIN
                ;WITH PlanillaJueves AS (
                    SELECT PS.Id, PS.IdEmpleado, PS.IdSemana, PS.SalarioBruto, S.FechaInicio, S.FechaFin, M.NumJueves
                    FROM dbo.PlanillaSemanal PS
                    INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                    INNER JOIN dbo.Mes M ON M.Id = S.IdMes
                    INNER JOIN dbo.Empleado E ON E.Id = PS.IdEmpleado
                    WHERE E.ValorDocumento = @DocProceso
                      AND @FechaProceso BETWEEN S.FechaInicio AND S.FechaFin
                ),
                DeduccionesCalculadas AS (
                    SELECT
                        PJ.Id AS IdPlanillaSemanal,
                        MA.Id AS IdMarcaAsistencia,
                        TD.IdTipoMovimiento,
                        SUM(
                            CASE
                                WHEN TD.EsPorcentual = 1 THEN PJ.SalarioBruto * TD.Valor
                                ELSE DE.MontoFijo / NULLIF(PJ.NumJueves, 0)
                            END
                        ) AS Monto
                    FROM PlanillaJueves PJ
                    INNER JOIN dbo.DeduccionEmpleado DE ON DE.IdEmpleado = PJ.IdEmpleado
                    INNER JOIN dbo.TipoDeduccion TD ON TD.Id = DE.IdTipoDeduccion
                    CROSS APPLY (
                        SELECT TOP 1 MA2.Id
                        FROM dbo.MarcaAsistencia MA2
                        WHERE MA2.IdEmpleado = PJ.IdEmpleado
                          AND MA2.Fecha BETWEEN PJ.FechaInicio AND PJ.FechaFin
                        ORDER BY MA2.Fecha DESC, MA2.Id DESC
                    ) MA
                    WHERE DE.FechaInicio <= PJ.FechaFin
                      AND (DE.FechaFin IS NULL OR DE.FechaFin >= PJ.FechaInicio)
                    GROUP BY PJ.Id, MA.Id, TD.IdTipoMovimiento
                )
                INSERT INTO dbo.MovimientoAsistencia (IdMarcaAsistencia, IdTipoMovimiento, CantidadHoras, Monto)
                SELECT DC.IdMarcaAsistencia, DC.IdTipoMovimiento, 0, DC.Monto
                FROM DeduccionesCalculadas DC
                WHERE DC.Monto > 0
                  AND NOT EXISTS (
                      SELECT 1
                      FROM dbo.MovimientoAsistencia MA
                      WHERE MA.IdMarcaAsistencia = DC.IdMarcaAsistencia
                        AND MA.IdTipoMovimiento = DC.IdTipoMovimiento
                        AND MA.CantidadHoras = 0
                        AND MA.Monto = DC.Monto
                  );

                UPDATE PS
                SET PS.TotalDeducciones = ISNULL(D.TotalDeducciones, 0),
                    PS.SalarioNeto = PS.SalarioBruto - ISNULL(D.TotalDeducciones, 0)
                FROM dbo.PlanillaSemanal PS
                INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                INNER JOIN dbo.Empleado E ON E.Id = PS.IdEmpleado
                OUTER APPLY (
                    SELECT SUM(MA.Monto) AS TotalDeducciones
                    FROM dbo.MarcaAsistencia Marca
                    INNER JOIN dbo.MovimientoAsistencia MA ON MA.IdMarcaAsistencia = Marca.Id
                    INNER JOIN dbo.TipoDeduccion TD ON TD.IdTipoMovimiento = MA.IdTipoMovimiento
                    WHERE Marca.IdEmpleado = PS.IdEmpleado
                      AND Marca.Fecha BETWEEN S.FechaInicio AND S.FechaFin
                ) D
                WHERE E.ValorDocumento = @DocProceso
                  AND @FechaProceso BETWEEN S.FechaInicio AND S.FechaFin;

                SET @IdEmpleadoCierre = NULL;
                SET @IdMesCierre = NULL;
                SET @IdPlanillaMensual = NULL;

                SELECT TOP 1
                    @IdEmpleadoCierre = PS.IdEmpleado,
                    @IdMesCierre = S.IdMes
                FROM dbo.PlanillaSemanal PS
                INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                INNER JOIN dbo.Empleado E ON E.Id = PS.IdEmpleado
                WHERE E.ValorDocumento = @DocProceso
                  AND @FechaProceso BETWEEN S.FechaInicio AND S.FechaFin;

                IF @IdEmpleadoCierre IS NOT NULL AND @IdMesCierre IS NOT NULL
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM dbo.PlanillaMensual
                        WHERE IdEmpleado = @IdEmpleadoCierre
                          AND IdMes = @IdMesCierre
                    )
                    BEGIN
                        INSERT INTO dbo.PlanillaMensual (IdEmpleado, IdMes, SalarioBruto, TotalDeducciones, SalarioNeto)
                        VALUES (@IdEmpleadoCierre, @IdMesCierre, 0, 0, 0);
                    END

                    SELECT @IdPlanillaMensual = Id
                    FROM dbo.PlanillaMensual
                    WHERE IdEmpleado = @IdEmpleadoCierre
                      AND IdMes = @IdMesCierre;

                    UPDATE PM
                    SET PM.SalarioBruto = ISNULL(T.SalarioBruto, 0),
                        PM.TotalDeducciones = ISNULL(T.TotalDeducciones, 0),
                        PM.SalarioNeto = ISNULL(T.SalarioNeto, 0)
                    FROM dbo.PlanillaMensual PM
                    OUTER APPLY (
                        SELECT
                            SUM(PS.SalarioBruto) AS SalarioBruto,
                            SUM(PS.TotalDeducciones) AS TotalDeducciones,
                            SUM(PS.SalarioNeto) AS SalarioNeto
                        FROM dbo.PlanillaSemanal PS
                        INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
                        WHERE PS.IdEmpleado = PM.IdEmpleado
                          AND S.IdMes = PM.IdMes
                    ) T
                    WHERE PM.Id = @IdPlanillaMensual;

                    DELETE FROM dbo.DeduccionXMes
                    WHERE IdPlanillaMensual = @IdPlanillaMensual;

                    INSERT INTO dbo.DeduccionXMes (IdPlanillaMensual, IdTipoDeduccion, MontoTotal)
                    SELECT
                        @IdPlanillaMensual,
                        TD.Id,
                        SUM(MA.Monto)
                    FROM dbo.MarcaAsistencia Marca
                    INNER JOIN dbo.MovimientoAsistencia MA ON MA.IdMarcaAsistencia = Marca.Id
                    INNER JOIN dbo.TipoDeduccion TD ON TD.IdTipoMovimiento = MA.IdTipoMovimiento
                    INNER JOIN dbo.Mes M ON M.Id = @IdMesCierre
                    WHERE Marca.IdEmpleado = @IdEmpleadoCierre
                      AND Marca.Fecha BETWEEN M.FechaInicio AND M.FechaFin
                    GROUP BY TD.Id
                    HAVING SUM(MA.Monto) > 0;
                END

                IF DATEPART(DAY, DATEADD(DAY, 1, @FechaProceso)) <= 7
                BEGIN
                    SET @ViernesSiguiente = DATEADD(DAY, 1, @FechaProceso);
                    SET @IdMesNuevo = NULL;
                    SET @FechaFinNuevoMes = (
                        SELECT MAX(Dia)
                        FROM (
                            SELECT DATEADD(DAY, n.n, @ViernesSiguiente) AS Dia
                            FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                        (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                        (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                        (31),(32),(33),(34),(35),(36),(37)) n(n)
                            WHERE DATEADD(DAY, n.n, @ViernesSiguiente) <= EOMONTH(@ViernesSiguiente)
                              AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @ViernesSiguiente)) = 'Thursday'
                        ) JuevesNuevoMes
                    );

                    SET @NumJueves = (
                        SELECT COUNT(*)
                        FROM (
                            SELECT DATEADD(DAY, n.n, @ViernesSiguiente) AS Dia
                            FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                                        (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                                        (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
                                        (31),(32),(33),(34),(35),(36),(37)) n(n)
                            WHERE DATEADD(DAY, n.n, @ViernesSiguiente) <= @FechaFinNuevoMes
                              AND DATENAME(WEEKDAY, DATEADD(DAY, n.n, @ViernesSiguiente)) = 'Thursday'
                        ) JuevesNuevoMes
                    );

                    SELECT @IdMesNuevo = Id
                    FROM dbo.Mes
                    WHERE FechaInicio = @ViernesSiguiente
                      AND FechaFin = @FechaFinNuevoMes;

                    IF @IdMesNuevo IS NULL
                    BEGIN
                        INSERT INTO dbo.Mes (FechaInicio, FechaFin, NumJueves)
                        VALUES (@ViernesSiguiente, @FechaFinNuevoMes, @NumJueves);
                        SET @IdMesNuevo = SCOPE_IDENTITY();
                    END

                    INSERT INTO dbo.PlanillaMensual (IdEmpleado, IdMes, SalarioBruto, TotalDeducciones, SalarioNeto)
                    SELECT E.Id, @IdMesNuevo, 0, 0, 0
                    FROM dbo.Empleado E
                    WHERE E.Activo = 1
                      AND NOT EXISTS (
                          SELECT 1
                          FROM dbo.PlanillaMensual PM
                          WHERE PM.IdEmpleado = E.Id
                            AND PM.IdMes = @IdMesNuevo
                      );
                END
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF CURSOR_STATUS('local', 'cur_emp') >= -1
            BEGIN
                IF CURSOR_STATUS('local', 'cur_emp') > -1 CLOSE cur_emp;
                DEALLOCATE cur_emp;
            END
            IF CURSOR_STATUS('local', 'cur_emp_del') >= -1
            BEGIN
                IF CURSOR_STATUS('local', 'cur_emp_del') > -1 CLOSE cur_emp_del;
                DEALLOCATE cur_emp_del;
            END
            IF CURSOR_STATUS('local', 'cur_des_ded') >= -1
            BEGIN
                IF CURSOR_STATUS('local', 'cur_des_ded') > -1 CLOSE cur_des_ded;
                DEALLOCATE cur_des_ded;
            END
            IF CURSOR_STATUS('local', 'cur_asis') >= -1
            BEGIN
                IF CURSOR_STATUS('local', 'cur_asis') > -1 CLOSE cur_asis;
                DEALLOCATE cur_asis;
            END
            IF CURSOR_STATUS('local', 'cur_jornada') >= -1
            BEGIN
                IF CURSOR_STATUS('local', 'cur_jornada') > -1 CLOSE cur_jornada;
                DEALLOCATE cur_jornada;
            END

            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

            INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
            VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());

            SET @OutRespuesta = 50008;
            CLOSE cur_operacion; DEALLOCATE cur_operacion;
            RETURN;
        END CATCH

        FETCH NEXT FROM cur_operacion INTO @FechaProceso, @DocProceso;
    END

    CLOSE cur_operacion; DEALLOCATE cur_operacion;
    SET @OutRespuesta = 0;
END;
GO
