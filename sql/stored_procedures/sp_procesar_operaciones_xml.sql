USE PlanillaObrera;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_procesar_operaciones_xml', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_procesar_operaciones_xml;
END
GO

CREATE PROCEDURE dbo.sp_procesar_operaciones_xml
    @inXmlData XML
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idDepartamento INT;
    DECLARE @cantidadDepartamento INT;
    DECLARE @idTipoDocumento INT;
    DECLARE @cantidadTipoDocumento INT;
    DECLARE @idTipoEventoEliminacion INT;
    DECLARE @idTipoEventoAsociacion INT;
    DECLARE @idTipoEventoDesasociacion INT;
    DECLARE @idTipoEventoAsistencia INT;
    DECLARE @idTipoEventoJornada INT;
    DECLARE @idMovOrdinario INT;
    DECLARE @idMovExtraNormal INT;
    DECLARE @idMovExtraDoble INT;
    DECLARE @fecha DATE;
    DECLARE @fechaSiguiente DATE;
    DECLARE @esJueves BIT;
    DECLARE @esPrimerEmpleado BIT;
    DECLARE @numeroFecha INT;
    DECLARE @totalFechas INT;
    DECLARE @numeroEmpleado INT;
    DECLARE @totalEmpleados INT;
    DECLARE @valorDocumento VARCHAR(50);
    DECLARE @idEmpleado INT;
    DECLARE @idUsuario INT;
    DECLARE @idPuesto INT;
    DECLARE @idSemanaActual INT;
    DECLARE @idSemanaNueva INT;
    DECLARE @idMesActual INT;
    DECLARE @idMesNuevo INT;
    DECLARE @idPlanillaSemanal INT;
    DECLARE @idPlanillaMensual INT;
    DECLARE @idHorarioJornada INT;
    DECLARE @idTipoJornada INT;
    DECLARE @fechaVigencia DATE;
    DECLARE @fechaInicioMes DATE;
    DECLARE @fechaFinMes DATE;
    DECLARE @primerDiaMesSiguiente DATE;
    DECLARE @primerViernesSiguiente DATE;
    DECLARE @numJueves TINYINT;
    DECLARE @diasHastaViernes INT;
    DECLARE @contadorDia INT;
    DECLARE @nombreEmpleado VARCHAR(100);
    DECLARE @puesto VARCHAR(100);
    DECLARE @cuentaBancaria VARCHAR(100);
    DECLARE @fechaContratacion DATE;
    DECLARE @username VARCHAR(64);
    DECLARE @passwordHash VARCHAR(128);
    DECLARE @realUsername VARCHAR(64);
    DECLARE @realPassword VARCHAR(128);
    DECLARE @montoFijo DECIMAL(12,2);
    DECLARE @nombreDeduccion VARCHAR(100);
    DECLARE @idTipoDeduccion INT;
    DECLARE @esObligatoria BIT;
    DECLARE @jornada VARCHAR(100);
    DECLARE @inicioSemana DATE;
    DECLARE @horaEntrada DATETIME;
    DECLARE @horaSalida DATETIME;
    DECLARE @horaInicioJornada TIME;
    DECLARE @horaFinJornada TIME;
    DECLARE @inicioJornada DATETIME;
    DECLARE @finJornada DATETIME;
    DECLARE @finOrdinario DATETIME;
    DECLARE @salarioXHora DECIMAL(14,2);
    DECLARE @horasOrdinarias DECIMAL(8,2);
    DECLARE @horasExtraNormal DECIMAL(8,2);
    DECLARE @horasExtraDoble DECIMAL(8,2);
    DECLARE @montoOrdinario DECIMAL(14,2);
    DECLARE @montoExtraNormal DECIMAL(14,2);
    DECLARE @montoExtraDoble DECIMAL(14,2);
    DECLARE @montoBruto DECIMAL(14,2);
    DECLARE @idMarcaAsistencia INT;
    DECLARE @extraCursor DATETIME;
    DECLARE @extraSiguiente DATETIME;
    DECLARE @fechaSegmento DATE;
    DECLARE @esDoble BIT;
    DECLARE @deduccionTotal DECIMAL(14,2);
    DECLARE @deduccionMonto DECIMAL(14,2);
    DECLARE @errorNumero INT;
    DECLARE @errorMensaje VARCHAR(MAX);
    DECLARE @errorProcedimiento VARCHAR(128);
    DECLARE @errorLinea INT;

    DECLARE @fechaOperacion TABLE (
        Numero INT NOT NULL IDENTITY(1,1) PRIMARY KEY
        , Fecha DATE NOT NULL UNIQUE
    );

    DECLARE @empleadoFecha TABLE (
        Numero INT NOT NULL PRIMARY KEY
        , ValorDocumento VARCHAR(50) NOT NULL UNIQUE
    );

    DECLARE @insertarEmpleado TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
        , Nombre VARCHAR(100) NOT NULL
        , Puesto VARCHAR(100) NOT NULL
        , CuentaBancaria VARCHAR(100) NULL
        , FechaContratacion DATE NOT NULL
        , Username VARCHAR(64) NULL
        , PasswordHash VARCHAR(128) NULL
    );

    DECLARE @eliminarEmpleado TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
    );

    DECLARE @asociaDeduccion TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
        , TipoDeduccion VARCHAR(100) NOT NULL
        , MontoFijo DECIMAL(12,2) NOT NULL
    );

    DECLARE @desasociaDeduccion TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
        , TipoDeduccion VARCHAR(100) NOT NULL
    );

    DECLARE @marcaAsistencia TABLE (
        FechaOperacion DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
        , HoraEntrada DATETIME NOT NULL
        , HoraSalida DATETIME NOT NULL
    );

    DECLARE @asignarJornada TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
        , Jornada VARCHAR(100) NOT NULL
        , InicioSemana DATE NOT NULL
    );

    SET @outResultCode = 0;

    BEGIN TRY
        IF (
            @inXmlData IS NULL
            OR @inXmlData.exist('/Operaciones') = 0
        )
        BEGIN
            INSERT INTO dbo.DBError (
                Mensaje
                , Severidad
                , Estado
            )
            VALUES (
                'Operaciones.xml no cumple el contrato oficial esperado'
                , 16
                , 1
            );

            SET @outResultCode = 50008;
            RETURN;
        END

        INSERT INTO @fechaOperacion (
            Fecha
        )
        SELECT
            X.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS X(FechaOperacion)
        ORDER BY
            X.FechaOperacion.value('@Fecha', 'DATE') ASC;

        INSERT INTO @insertarEmpleado (
            Fecha
            , ValorDocumento
            , Nombre
            , Puesto
            , CuentaBancaria
            , FechaContratacion
            , Username
            , PasswordHash
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
            , X.Operacion.value('@Nombre', 'VARCHAR(100)') AS Nombre
            , X.Operacion.value('@Puesto', 'VARCHAR(100)') AS Puesto
            , X.Operacion.value('@CuentaBancaria', 'VARCHAR(100)') AS CuentaBancaria
            , ISNULL(
                X.Operacion.value('@FechaContratacion', 'DATE')
                , F.FechaOperacion.value('@Fecha', 'DATE')
            ) AS FechaContratacion
            , X.Operacion.value('@Username', 'VARCHAR(64)') AS Username
            , X.Operacion.value('@Password', 'VARCHAR(128)') AS PasswordHash
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('InsertarEmpleado') AS X(Operacion);

        INSERT INTO @eliminarEmpleado (
            Fecha
            , ValorDocumento
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('EliminarEmpleado') AS X(Operacion);

        INSERT INTO @asociaDeduccion (
            Fecha
            , ValorDocumento
            , TipoDeduccion
            , MontoFijo
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
            , X.Operacion.value('@TipoDeduccion', 'VARCHAR(100)') AS TipoDeduccion
            , ISNULL(X.Operacion.value('@MontoFijo', 'DECIMAL(12,2)'), 0) AS MontoFijo
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('AsociaEmpleadoConDeduccion') AS X(Operacion);

        INSERT INTO @desasociaDeduccion (
            Fecha
            , ValorDocumento
            , TipoDeduccion
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
            , X.Operacion.value('@TipoDeduccion', 'VARCHAR(100)') AS TipoDeduccion
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('DesasociaEmpleadoConDeduccion') AS X(Operacion);

        INSERT INTO @marcaAsistencia (
            FechaOperacion
            , ValorDocumento
            , HoraEntrada
            , HoraSalida
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS FechaOperacion
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
            , X.Operacion.value('@HoraEntrada', 'DATETIME') AS HoraEntrada
            , X.Operacion.value('@HoraSalida', 'DATETIME') AS HoraSalida
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('MarcaAsistencia') AS X(Operacion);

        INSERT INTO @asignarJornada (
            Fecha
            , ValorDocumento
            , Jornada
            , InicioSemana
        )
        SELECT
            F.FechaOperacion.value('@Fecha', 'DATE') AS Fecha
            , X.Operacion.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
            , X.Operacion.value('@Jornada', 'VARCHAR(100)') AS Jornada
            , ISNULL(
                X.Operacion.value('@InicioSemana', 'DATE')
                , DATEADD(DAY, 1, F.FechaOperacion.value('@Fecha', 'DATE'))
            ) AS InicioSemana
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
        CROSS APPLY F.FechaOperacion.nodes('AsignarJornada') AS X(Operacion);

        SELECT
            @cantidadDepartamento = COUNT(1)
        FROM dbo.Departamento AS D;

        SELECT
            @cantidadTipoDocumento = COUNT(1)
        FROM dbo.TipoDocIdentidad AS TD;

        IF (
            @cantidadDepartamento = 1
            AND @cantidadTipoDocumento = 1
        )
        BEGIN
            SELECT
                @idDepartamento = D.Id
            FROM dbo.Departamento AS D;

            SELECT
                @idTipoDocumento = TD.Id
            FROM dbo.TipoDocIdentidad AS TD;
        END

        SELECT
            @idTipoEventoEliminacion = TE.Id
        FROM dbo.TipoEvento AS TE
        WHERE (TE.Nombre = 'Borrado exitoso');

        SELECT
            @idTipoEventoAsociacion = TE.Id
        FROM dbo.TipoEvento AS TE
        WHERE (TE.Nombre = 'Asociar deduccion');

        SELECT
            @idTipoEventoDesasociacion = TE.Id
        FROM dbo.TipoEvento AS TE
        WHERE (TE.Nombre = 'Desasociar deduccion');

        SELECT
            @idTipoEventoAsistencia = TE.Id
        FROM dbo.TipoEvento AS TE
        WHERE (TE.Nombre = 'Ingreso de marcas de asistencia');

        SELECT
            @idTipoEventoJornada = TE.Id
        FROM dbo.TipoEvento AS TE
        WHERE (TE.Nombre = 'Ingreso nuevas jornadas');

        SELECT
            @idMovOrdinario = TM.Id
        FROM dbo.TipoMovimiento AS TM
        WHERE (TM.Nombre = 'Credito Horas Ordinarias');

        SELECT
            @idMovExtraNormal = TM.Id
        FROM dbo.TipoMovimiento AS TM
        WHERE (TM.Nombre = 'Credito Horas Extra Normales');

        SELECT
            @idMovExtraDoble = TM.Id
        FROM dbo.TipoMovimiento AS TM
        WHERE (TM.Nombre = 'Credito Horas Extra Dobles');

        IF (
            @idDepartamento IS NULL
            OR @idTipoDocumento IS NULL
            OR @idMovOrdinario IS NULL
            OR @idMovExtraNormal IS NULL
            OR @idMovExtraDoble IS NULL
        )
        BEGIN
            INSERT INTO dbo.DBError (
                Mensaje
                , Severidad
                , Estado
            )
            VALUES (
                'Catalogos requeridos incompletos para procesar operaciones'
                , 16
                , 1
            );

            SET @outResultCode = 50008;
            RETURN;
        END

        SELECT
            @totalFechas = COUNT(1)
        FROM @fechaOperacion AS FO;

        SET @numeroFecha = 1;

        WHILE (@numeroFecha <= @totalFechas)
        BEGIN
            SELECT
                @fecha = FO.Fecha
            FROM @fechaOperacion AS FO
            WHERE (FO.Numero = @numeroFecha);

            SET @fechaSiguiente = DATEADD(DAY, 1, @fecha);
            SET @esJueves = CASE
                WHEN (DATEDIFF(DAY, '19000104', @fecha) % 7 = 0) THEN 1
                ELSE 0
            END;

            DELETE EF
            FROM @empleadoFecha AS EF;

            INSERT INTO @empleadoFecha (
                Numero
                , ValorDocumento
            )
            SELECT
                ROW_NUMBER() OVER (
                    ORDER BY O.ValorDocumento ASC
                ) AS Numero
                , O.ValorDocumento
            FROM (
                SELECT
                    IE.ValorDocumento
                FROM @insertarEmpleado AS IE
                WHERE (IE.Fecha = @fecha)
                UNION
                SELECT
                    ED.ValorDocumento
                FROM @eliminarEmpleado AS ED
                WHERE (ED.Fecha = @fecha)
                UNION
                SELECT
                    AD.ValorDocumento
                FROM @asociaDeduccion AS AD
                WHERE (AD.Fecha = @fecha)
                UNION
                SELECT
                    DD.ValorDocumento
                FROM @desasociaDeduccion AS DD
                WHERE (DD.Fecha = @fecha)
                UNION
                SELECT
                    MA.ValorDocumento
                FROM @marcaAsistencia AS MA
                WHERE (MA.FechaOperacion = @fecha)
                UNION
                SELECT
                    AJ.ValorDocumento
                FROM @asignarJornada AS AJ
                WHERE (AJ.Fecha = @fecha)
                UNION
                SELECT
                    E.ValorDocumento
                FROM dbo.Empleado AS E
                INNER JOIN dbo.PlanillaSemanal AS PS
                    ON PS.IdEmpleado = E.Id
                INNER JOIN dbo.Semana AS S
                    ON S.Id = PS.IdSemana
                WHERE (@esJueves = 1)
                    AND (E.Activo = 1)
                    AND (@fecha BETWEEN S.FechaInicio AND S.FechaFin)
            ) AS O
            WHERE (NULLIF(O.ValorDocumento, '') IS NOT NULL)
            ORDER BY
                O.ValorDocumento ASC;

            SELECT
                @totalEmpleados = COUNT(1)
            FROM @empleadoFecha AS EF;

            SET @numeroEmpleado = 1;

            WHILE (@numeroEmpleado <= @totalEmpleados)
            BEGIN
                SELECT
                    @valorDocumento = EF.ValorDocumento
                FROM @empleadoFecha AS EF
                WHERE (EF.Numero = @numeroEmpleado);

                SET @esPrimerEmpleado = CASE
                    WHEN (@numeroEmpleado = 1) THEN 1
                    ELSE 0
                END;
                SET @idEmpleado = NULL;
                SET @idUsuario = NULL;
                SET @idPuesto = NULL;
                SET @idSemanaActual = NULL;
                SET @idSemanaNueva = NULL;
                SET @idMesActual = NULL;
                SET @idMesNuevo = NULL;
                SET @idPlanillaSemanal = NULL;
                SET @idPlanillaMensual = NULL;
                SET @idHorarioJornada = NULL;
                SET @idTipoJornada = NULL;
                SET @fechaVigencia = NULL;
                SET @nombreEmpleado = NULL;
                SET @puesto = NULL;
                SET @cuentaBancaria = NULL;
                SET @fechaContratacion = NULL;
                SET @username = NULL;
                SET @passwordHash = NULL;
                SET @realUsername = NULL;
                SET @realPassword = NULL;
                SET @montoFijo = 0;
                SET @nombreDeduccion = NULL;
                SET @idTipoDeduccion = NULL;
                SET @esObligatoria = NULL;
                SET @jornada = NULL;
                SET @inicioSemana = NULL;
                SET @horaEntrada = NULL;
                SET @horaSalida = NULL;
                SET @horaInicioJornada = NULL;
                SET @horaFinJornada = NULL;
                SET @inicioJornada = NULL;
                SET @finJornada = NULL;
                SET @finOrdinario = NULL;
                SET @salarioXHora = 0;
                SET @horasOrdinarias = 0;
                SET @horasExtraNormal = 0;
                SET @horasExtraDoble = 0;
                SET @montoOrdinario = 0;
                SET @montoExtraNormal = 0;
                SET @montoExtraDoble = 0;
                SET @montoBruto = 0;
                SET @idMarcaAsistencia = NULL;
                SET @deduccionTotal = 0;
                SET @errorNumero = NULL;
                SET @errorMensaje = NULL;
                SET @errorProcedimiento = NULL;
                SET @errorLinea = NULL;

                SELECT
                    @nombreEmpleado = IE.Nombre
                    , @puesto = IE.Puesto
                    , @cuentaBancaria = IE.CuentaBancaria
                    , @fechaContratacion = IE.FechaContratacion
                    , @username = IE.Username
                    , @passwordHash = IE.PasswordHash
                FROM @insertarEmpleado AS IE
                WHERE (IE.Fecha = @fecha)
                    AND (IE.ValorDocumento = @valorDocumento);

                IF (@puesto IS NOT NULL)
                BEGIN
                    SELECT
                        @idPuesto = P.Id
                    FROM dbo.Puesto AS P
                    WHERE (P.Nombre = @puesto);

                    SET @realUsername = ISNULL(NULLIF(@username, ''), @valorDocumento);
                    SET @realPassword = ISNULL(NULLIF(@passwordHash, ''), @valorDocumento);
                END

                SET @diasHastaViernes =
                    (7 - (DATEDIFF(DAY, '19000105', @fecha) % 7)) % 7;

                IF (@diasHastaViernes = 0)
                BEGIN
                    SET @diasHastaViernes = 7;
                END

                SET @fechaVigencia = DATEADD(DAY, @diasHastaViernes, @fecha);

                SELECT
                    @idEmpleado = E.Id
                    , @idUsuario = E.IdUsuario
                FROM dbo.Empleado AS E
                WHERE (E.ValorDocumento = @valorDocumento);

                SELECT
                    @horaEntrada = MA.HoraEntrada
                    , @horaSalida = MA.HoraSalida
                FROM @marcaAsistencia AS MA
                WHERE (MA.FechaOperacion = @fecha)
                    AND (MA.ValorDocumento = @valorDocumento);

                IF (
                    @horaEntrada IS NOT NULL
                    AND @idEmpleado IS NOT NULL
                )
                BEGIN
                    SELECT
                        @idHorarioJornada = HJ.Id
                        , @idSemanaActual = HJ.IdSemana
                        , @horaInicioJornada = TJ.HoraInicio
                        , @horaFinJornada = TJ.HoraFin
                        , @salarioXHora = CAST(P.SalarioXHora AS DECIMAL(14,2))
                    FROM dbo.Empleado AS E
                    INNER JOIN dbo.Puesto AS P
                        ON P.Id = E.IdPuesto
                    INNER JOIN dbo.HorarioJornada AS HJ
                        ON HJ.IdEmpleado = E.Id
                    INNER JOIN dbo.Semana AS S
                        ON S.Id = HJ.IdSemana
                    INNER JOIN dbo.TipoJornada AS TJ
                        ON TJ.Id = HJ.IdTipoJornada
                    WHERE (E.Id = @idEmpleado)
                        AND (CAST(@horaEntrada AS DATE) BETWEEN S.FechaInicio AND S.FechaFin);

                    SET @inicioJornada = DATEADD(
                        SECOND
                        , DATEDIFF(SECOND, CAST('00:00:00' AS TIME), @horaInicioJornada)
                        , CAST(CAST(@horaEntrada AS DATE) AS DATETIME)
                    );
                    SET @finJornada = DATEADD(
                        SECOND
                        , DATEDIFF(SECOND, CAST('00:00:00' AS TIME), @horaFinJornada)
                        , CAST(CAST(@horaEntrada AS DATE) AS DATETIME)
                    );

                    IF (@horaFinJornada <= @horaInicioJornada)
                    BEGIN
                        SET @finJornada = DATEADD(DAY, 1, @finJornada);
                    END

                    SET @finOrdinario = CASE
                        WHEN (@horaSalida < @finJornada) THEN @horaSalida
                        ELSE @finJornada
                    END;

                    IF (@finOrdinario > @horaEntrada)
                    BEGIN
                        SET @horasOrdinarias = DATEDIFF(MINUTE, @horaEntrada, @finOrdinario) / 60;
                    END

                    IF (@horasOrdinarias > 8)
                    BEGIN
                        SET @horasOrdinarias = 8;
                    END

                    IF (@horaSalida > @finJornada)
                    BEGIN
                        SET @extraCursor = @finJornada;

                        WHILE (DATEADD(HOUR, 1, @extraCursor) <= @horaSalida)
                        BEGIN
                            SET @extraSiguiente = DATEADD(HOUR, 1, @extraCursor);
                            SET @fechaSegmento = CAST(@extraCursor AS DATE);
                            SET @esDoble = CASE
                                WHEN (DATEDIFF(DAY, '19000107', @fechaSegmento) % 7 = 0)
                                    OR (EXISTS (
                                        SELECT
                                            1
                                        FROM dbo.Feriado AS F
                                        WHERE (F.Fecha = @fechaSegmento)
                                    ))
                                    THEN 1
                                ELSE 0
                            END;

                            IF (@esDoble = 1)
                            BEGIN
                                SET @horasExtraDoble = @horasExtraDoble + 1;
                            END
                            ELSE
                            BEGIN
                                SET @horasExtraNormal = @horasExtraNormal + 1;
                            END

                            SET @extraCursor = @extraSiguiente;
                        END
                    END

                    SET @montoOrdinario = @horasOrdinarias * @salarioXHora;
                    SET @montoExtraNormal = @horasExtraNormal * @salarioXHora * 1.5;
                    SET @montoExtraDoble = @horasExtraDoble * @salarioXHora * 2.0;
                    SET @montoBruto = @montoOrdinario + @montoExtraNormal + @montoExtraDoble;
                END

                BEGIN TRY
                    BEGIN TRANSACTION;

                    IF (@esPrimerEmpleado = 1 AND @esJueves = 1)
                    BEGIN
                        SET @fechaInicioMes = NULL;
                        SET @fechaFinMes = NULL;
                        SET @primerViernesSiguiente = NULL;
                        SET @numJueves = 0;

                        SELECT
                            @idMesNuevo = M.Id
                        FROM dbo.Mes AS M
                        WHERE (@fechaSiguiente BETWEEN M.FechaInicio AND M.FechaFin);

                        IF (@idMesNuevo IS NULL)
                        BEGIN
                            SET @fechaInicioMes = @fechaSiguiente;
                            SET @primerDiaMesSiguiente = DATEFROMPARTS(
                                YEAR(DATEADD(MONTH, 1, @fechaInicioMes))
                                , MONTH(DATEADD(MONTH, 1, @fechaInicioMes))
                                , 1
                            );
                            SET @contadorDia = 0;

                            WHILE (@contadorDia <= 6)
                            BEGIN
                                IF (
                                    DATEDIFF(
                                        DAY
                                        , '19000105'
                                        , DATEADD(DAY, @contadorDia, @primerDiaMesSiguiente)
                                    ) % 7 = 0
                                )
                                BEGIN
                                    SET @primerViernesSiguiente =
                                        DATEADD(DAY, @contadorDia, @primerDiaMesSiguiente);
                                    SET @contadorDia = 7;
                                END
                                ELSE
                                BEGIN
                                    SET @contadorDia = @contadorDia + 1;
                                END
                            END

                            SET @fechaFinMes = DATEADD(DAY, -1, @primerViernesSiguiente);
                            SET @contadorDia = 0;

                            WHILE (DATEADD(DAY, @contadorDia, @fechaInicioMes) <= @fechaFinMes)
                            BEGIN
                                IF (
                                    DATEDIFF(
                                        DAY
                                        , '19000104'
                                        , DATEADD(DAY, @contadorDia, @fechaInicioMes)
                                    ) % 7 = 0
                                )
                                BEGIN
                                    SET @numJueves = @numJueves + 1;
                                END

                                SET @contadorDia = @contadorDia + 1;
                            END

                            INSERT INTO dbo.Mes (
                                FechaInicio
                                , FechaFin
                                , NumJueves
                            )
                            SELECT
                                @fechaInicioMes
                                , @fechaFinMes
                                , @numJueves
                            WHERE (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.Mes AS M
                                WHERE (M.FechaInicio = @fechaInicioMes)
                                    AND (M.FechaFin = @fechaFinMes)
                            ));
                        END

                        SELECT
                            @idMesNuevo = M.Id
                        FROM dbo.Mes AS M
                        WHERE (@fechaSiguiente BETWEEN M.FechaInicio AND M.FechaFin);

                        INSERT INTO dbo.Semana (
                            IdMes
                            , FechaInicio
                            , FechaFin
                        )
                        SELECT
                            @idMesNuevo
                            , @fechaSiguiente
                            , DATEADD(DAY, 6, @fechaSiguiente)
                        WHERE (@idMesNuevo IS NOT NULL)
                            AND (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.Semana AS S
                                WHERE (S.FechaInicio = @fechaSiguiente)
                            ));
                    END

                    IF (@nombreEmpleado IS NOT NULL)
                    BEGIN
                        IF (@idPuesto IS NULL)
                        BEGIN
                            THROW 51001, 'Puesto de empleado no existe en catalogo', 1;
                        END

                        IF (NOT EXISTS (
                            SELECT
                                1
                            FROM dbo.Usuario AS U
                            WHERE (U.Username = @realUsername)
                        ))
                        BEGIN
                            INSERT INTO dbo.Usuario (
                                Username
                                , PasswordHash
                                , Tipo
                            )
                            VALUES (
                                @realUsername
                                , @realPassword
                                , 'empleado'
                            );
                        END

                        SELECT
                            @idUsuario = U.Id
                        FROM dbo.Usuario AS U
                        WHERE (U.Username = @realUsername);

                        IF (NOT EXISTS (
                            SELECT
                                1
                            FROM dbo.Empleado AS E
                            WHERE (E.ValorDocumento = @valorDocumento)
                        ))
                        BEGIN
                            INSERT INTO dbo.Empleado (
                                IdPuesto
                                , IdDepartamento
                                , IdTipoDocumento
                                , IdUsuario
                                , ValorDocumento
                                , Nombre
                                , CuentaBancaria
                                , FechaContratacion
                                , Activo
                            )
                            VALUES (
                                @idPuesto
                                , @idDepartamento
                                , @idTipoDocumento
                                , @idUsuario
                                , @valorDocumento
                                , @nombreEmpleado
                                , ISNULL(NULLIF(@cuentaBancaria, ''), @valorDocumento)
                                , @fechaContratacion
                                , 1
                            );
                        END

                        SELECT
                            @idEmpleado = E.Id
                            , @idUsuario = E.IdUsuario
                        FROM dbo.Empleado AS E
                        WHERE (E.ValorDocumento = @valorDocumento);
                    END

                    SELECT
                        @idEmpleado = E.Id
                        , @idUsuario = E.IdUsuario
                    FROM dbo.Empleado AS E
                    WHERE (E.ValorDocumento = @valorDocumento);

                    SELECT
                        @idSemanaNueva = S.Id
                    FROM dbo.Semana AS S
                    WHERE (S.FechaInicio = @fechaSiguiente);

                    IF (@idEmpleado IS NOT NULL)
                    BEGIN
                        SELECT
                            @idSemanaActual = S.Id
                            , @idMesActual = S.IdMes
                        FROM dbo.Semana AS S
                        WHERE (@fecha BETWEEN S.FechaInicio AND S.FechaFin);

                        IF (@idSemanaActual IS NOT NULL)
                        BEGIN
                            INSERT INTO dbo.PlanillaSemanal (
                                IdEmpleado
                                , IdSemana
                                , SalarioBruto
                                , TotalDeducciones
                                , SalarioNeto
                                , HorasOrdinarias
                                , HorasExtraNormal
                                , HorasExtraDoble
                            )
                            SELECT
                                @idEmpleado
                                , @idSemanaActual
                                , 0
                                , 0
                                , 0
                                , 0
                                , 0
                                , 0
                            WHERE (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.PlanillaSemanal AS PS
                                WHERE (PS.IdEmpleado = @idEmpleado)
                                    AND (PS.IdSemana = @idSemanaActual)
                            ));

                            INSERT INTO dbo.PlanillaMensual (
                                IdEmpleado
                                , IdMes
                                , SalarioBruto
                                , TotalDeducciones
                                , SalarioNeto
                            )
                            SELECT
                                @idEmpleado
                                , @idMesActual
                                , 0
                                , 0
                                , 0
                            WHERE (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.PlanillaMensual AS PM
                                WHERE (PM.IdEmpleado = @idEmpleado)
                                    AND (PM.IdMes = @idMesActual)
                            ));
                        END

                        SELECT
                            @idPlanillaMensual = PM.Id
                        FROM dbo.PlanillaMensual AS PM
                        WHERE (PM.IdEmpleado = @idEmpleado)
                            AND (PM.IdMes = @idMesActual);

                        INSERT INTO dbo.DeduccionEmpleado (
                            IdEmpleado
                            , IdTipoDeduccion
                            , MontoFijo
                            , FechaInicio
                            , FechaFin
                        )
                        SELECT
                            @idEmpleado
                            , TD.Id
                            , AD.MontoFijo
                            , @fechaVigencia
                            , NULL
                        FROM @asociaDeduccion AS AD
                        INNER JOIN dbo.TipoDeduccion AS TD
                            ON TD.Nombre = AD.TipoDeduccion
                        WHERE (AD.Fecha = @fecha)
                            AND (AD.ValorDocumento = @valorDocumento)
                            AND (TD.EsObligatoria = 0)
                            AND (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.DeduccionEmpleado AS DE
                                WHERE (DE.IdEmpleado = @idEmpleado)
                                    AND (DE.IdTipoDeduccion = TD.Id)
                                    AND (DE.FechaFin IS NULL)
                            ));

                        INSERT INTO dbo.BitacoraEvento (
                            IdTipoEvento
                            , IdUsuario
                            , IP
                            , Descripcion
                        )
                        SELECT
                            @idTipoEventoAsociacion
                            , @idUsuario
                            , '127.0.0.1'
                            , 'Asociacion de deduccion para empleado con documento: '
                                + @valorDocumento
                        FROM @asociaDeduccion AS AD
                        INNER JOIN dbo.TipoDeduccion AS TD
                            ON TD.Nombre = AD.TipoDeduccion
                        WHERE (AD.Fecha = @fecha)
                            AND (AD.ValorDocumento = @valorDocumento)
                            AND (TD.EsObligatoria = 0)
                            AND (@idTipoEventoAsociacion IS NOT NULL);

                        UPDATE DE
                        SET
                            DE.FechaFin = @fechaVigencia
                        FROM dbo.DeduccionEmpleado AS DE
                        INNER JOIN dbo.TipoDeduccion AS TD
                            ON TD.Id = DE.IdTipoDeduccion
                        INNER JOIN @desasociaDeduccion AS DD
                            ON DD.TipoDeduccion = TD.Nombre
                        WHERE (DE.IdEmpleado = @idEmpleado)
                            AND (DD.Fecha = @fecha)
                            AND (DD.ValorDocumento = @valorDocumento)
                            AND (TD.EsObligatoria = 0)
                            AND (DE.FechaFin IS NULL);

                        INSERT INTO dbo.BitacoraEvento (
                            IdTipoEvento
                            , IdUsuario
                            , IP
                            , Descripcion
                        )
                        SELECT
                            @idTipoEventoDesasociacion
                            , @idUsuario
                            , '127.0.0.1'
                            , 'Desasociacion de deduccion para empleado con documento: '
                                + @valorDocumento
                        FROM @desasociaDeduccion AS DD
                        INNER JOIN dbo.TipoDeduccion AS TD
                            ON TD.Nombre = DD.TipoDeduccion
                        WHERE (DD.Fecha = @fecha)
                            AND (DD.ValorDocumento = @valorDocumento)
                            AND (TD.EsObligatoria = 0)
                            AND (@idTipoEventoDesasociacion IS NOT NULL);

                        IF (
                            @horaEntrada IS NOT NULL
                            AND @idHorarioJornada IS NOT NULL
                            AND NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.MarcaAsistencia AS MA
                                WHERE (MA.IdEmpleado = @idEmpleado)
                                    AND (MA.Fecha = CAST(@horaEntrada AS DATE))
                            )
                        )
                        BEGIN
                            INSERT INTO dbo.MarcaAsistencia (
                                IdEmpleado
                                , IdHorarioJornada
                                , Fecha
                                , HoraEntrada
                                , HoraSalida
                            )
                            VALUES (
                                @idEmpleado
                                , @idHorarioJornada
                                , CAST(@horaEntrada AS DATE)
                                , @horaEntrada
                                , @horaSalida
                            );

                            SET @idMarcaAsistencia = SCOPE_IDENTITY();

                            IF (@horasOrdinarias > 0)
                            BEGIN
                                INSERT INTO dbo.MovimientoAsistencia (
                                    IdMarcaAsistencia
                                    , IdTipoMovimiento
                                    , CantidadHoras
                                    , Monto
                                )
                                VALUES (
                                    @idMarcaAsistencia
                                    , @idMovOrdinario
                                    , @horasOrdinarias
                                    , @montoOrdinario
                                );
                            END

                            IF (@horasExtraNormal > 0)
                            BEGIN
                                INSERT INTO dbo.MovimientoAsistencia (
                                    IdMarcaAsistencia
                                    , IdTipoMovimiento
                                    , CantidadHoras
                                    , Monto
                                )
                                VALUES (
                                    @idMarcaAsistencia
                                    , @idMovExtraNormal
                                    , @horasExtraNormal
                                    , @montoExtraNormal
                                );
                            END

                            IF (@horasExtraDoble > 0)
                            BEGIN
                                INSERT INTO dbo.MovimientoAsistencia (
                                    IdMarcaAsistencia
                                    , IdTipoMovimiento
                                    , CantidadHoras
                                    , Monto
                                )
                                VALUES (
                                    @idMarcaAsistencia
                                    , @idMovExtraDoble
                                    , @horasExtraDoble
                                    , @montoExtraDoble
                                );
                            END

                            UPDATE PS
                            SET
                                PS.SalarioBruto = PS.SalarioBruto + @montoBruto
                                , PS.HorasOrdinarias = PS.HorasOrdinarias + @horasOrdinarias
                                , PS.HorasExtraNormal = PS.HorasExtraNormal + @horasExtraNormal
                                , PS.HorasExtraDoble = PS.HorasExtraDoble + @horasExtraDoble
                                , PS.SalarioNeto =
                                    (PS.SalarioBruto + @montoBruto) - PS.TotalDeducciones
                            FROM dbo.PlanillaSemanal AS PS
                            WHERE (PS.IdEmpleado = @idEmpleado)
                                AND (PS.IdSemana = @idSemanaActual);

                            INSERT INTO dbo.BitacoraEvento (
                                IdTipoEvento
                                , IdUsuario
                                , IP
                                , Descripcion
                            )
                            SELECT
                                @idTipoEventoAsistencia
                                , @idUsuario
                                , '127.0.0.1'
                                , 'Ingreso de marca de asistencia para empleado: '
                                    + @valorDocumento
                            WHERE (@idTipoEventoAsistencia IS NOT NULL);
                        END

                        IF (@esJueves = 1 AND @idSemanaActual IS NOT NULL)
                        BEGIN
                            SELECT
                                @idPlanillaSemanal = PS.Id
                            FROM dbo.PlanillaSemanal AS PS
                            WHERE (PS.IdEmpleado = @idEmpleado)
                                AND (PS.IdSemana = @idSemanaActual);

                            IF (@idPlanillaMensual IS NULL)
                            BEGIN
                                SELECT
                                    @idPlanillaMensual = PM.Id
                                FROM dbo.PlanillaMensual AS PM
                                WHERE (PM.IdEmpleado = @idEmpleado)
                                    AND (PM.IdMes = @idMesActual);
                            END

                            SELECT
                                @idMarcaAsistencia = MA.Id
                            FROM dbo.MarcaAsistencia AS MA
                            INNER JOIN dbo.HorarioJornada AS HJ
                                ON HJ.Id = MA.IdHorarioJornada
                            WHERE (MA.IdEmpleado = @idEmpleado)
                                AND (HJ.IdSemana = @idSemanaActual)
                                AND (MA.Id = (
                                    SELECT
                                        MAX(MAI.Id)
                                    FROM dbo.MarcaAsistencia AS MAI
                                    INNER JOIN dbo.HorarioJornada AS HJI
                                        ON HJI.Id = MAI.IdHorarioJornada
                                    WHERE (MAI.IdEmpleado = @idEmpleado)
                                        AND (HJI.IdSemana = @idSemanaActual)
                                ));

                            INSERT INTO dbo.MovimientoAsistencia (
                                IdMarcaAsistencia
                                , IdTipoMovimiento
                                , CantidadHoras
                                , Monto
                            )
                            SELECT
                                @idMarcaAsistencia
                                , TD.IdTipoMovimiento
                                , 0
                                , CASE
                                    WHEN (TD.EsPorcentual = 1) THEN PS.SalarioBruto * TD.Valor
                                    ELSE DE.MontoFijo / NULLIF(M.NumJueves, 0)
                                END
                            FROM dbo.PlanillaSemanal AS PS
                            INNER JOIN dbo.Semana AS S
                                ON S.Id = PS.IdSemana
                            INNER JOIN dbo.Mes AS M
                                ON M.Id = S.IdMes
                            INNER JOIN dbo.DeduccionEmpleado AS DE
                                ON DE.IdEmpleado = PS.IdEmpleado
                            INNER JOIN dbo.TipoDeduccion AS TD
                                ON TD.Id = DE.IdTipoDeduccion
                            WHERE (PS.Id = @idPlanillaSemanal)
                                AND (@idMarcaAsistencia IS NOT NULL)
                                AND (DE.FechaInicio <= S.FechaInicio)
                                AND (DE.FechaFin IS NULL OR DE.FechaFin > S.FechaInicio)
                                AND (NOT EXISTS (
                                    SELECT
                                        1
                                    FROM dbo.MovimientoAsistencia AS MV
                                    WHERE (MV.IdMarcaAsistencia = @idMarcaAsistencia)
                                        AND (MV.IdTipoMovimiento = TD.IdTipoMovimiento)
                                        AND (MV.CantidadHoras = 0)
                                ));

                            SELECT
                                @deduccionTotal = ISNULL(SUM(MV.Monto), 0)
                            FROM dbo.MarcaAsistencia AS MA
                            INNER JOIN dbo.HorarioJornada AS HJ
                                ON HJ.Id = MA.IdHorarioJornada
                            INNER JOIN dbo.MovimientoAsistencia AS MV
                                ON MV.IdMarcaAsistencia = MA.Id
                            INNER JOIN dbo.TipoDeduccion AS TD
                                ON TD.IdTipoMovimiento = MV.IdTipoMovimiento
                            WHERE (MA.IdEmpleado = @idEmpleado)
                                AND (HJ.IdSemana = @idSemanaActual);

                            UPDATE PS
                            SET
                                PS.TotalDeducciones = @deduccionTotal
                                , PS.SalarioNeto = PS.SalarioBruto - @deduccionTotal
                            FROM dbo.PlanillaSemanal AS PS
                            WHERE (PS.Id = @idPlanillaSemanal);

                            UPDATE PM
                            SET
                                PM.SalarioBruto = PM.SalarioBruto + PS.SalarioBruto
                                , PM.TotalDeducciones =
                                    PM.TotalDeducciones + PS.TotalDeducciones
                                , PM.SalarioNeto =
                                    PM.SalarioNeto + PS.SalarioNeto
                            FROM dbo.PlanillaMensual AS PM
                            INNER JOIN dbo.PlanillaSemanal AS PS
                                ON PS.IdEmpleado = PM.IdEmpleado
                            WHERE (PM.Id = @idPlanillaMensual)
                                AND (PS.Id = @idPlanillaSemanal);

                            INSERT INTO dbo.DeduccionXMes (
                                IdPlanillaMensual
                                , IdTipoDeduccion
                                , MontoTotal
                            )
                            SELECT
                                @idPlanillaMensual
                                , TD.Id
                                , 0
                            FROM dbo.DeduccionEmpleado AS DE
                            INNER JOIN dbo.TipoDeduccion AS TD
                                ON TD.Id = DE.IdTipoDeduccion
                            WHERE (DE.IdEmpleado = @idEmpleado)
                                AND (DE.FechaInicio <= @fechaSiguiente)
                                AND (DE.FechaFin IS NULL OR DE.FechaFin > @fechaSiguiente)
                                AND (NOT EXISTS (
                                    SELECT
                                        1
                                    FROM dbo.DeduccionXMes AS DXM
                                    WHERE (DXM.IdPlanillaMensual = @idPlanillaMensual)
                                        AND (DXM.IdTipoDeduccion = TD.Id)
                                ));

                            UPDATE DXM
                            SET
                                DXM.MontoTotal = DXM.MontoTotal + D.Monto
                            FROM dbo.DeduccionXMes AS DXM
                            INNER JOIN (
                                SELECT
                                    TD.Id AS IdTipoDeduccion
                                    , SUM(MV.Monto) AS Monto
                                FROM dbo.MarcaAsistencia AS MA
                                INNER JOIN dbo.HorarioJornada AS HJ
                                    ON HJ.Id = MA.IdHorarioJornada
                                INNER JOIN dbo.MovimientoAsistencia AS MV
                                    ON MV.IdMarcaAsistencia = MA.Id
                                INNER JOIN dbo.TipoDeduccion AS TD
                                    ON TD.IdTipoMovimiento = MV.IdTipoMovimiento
                                WHERE (MA.IdEmpleado = @idEmpleado)
                                    AND (HJ.IdSemana = @idSemanaActual)
                                GROUP BY
                                    TD.Id
                            ) AS D
                                ON D.IdTipoDeduccion = DXM.IdTipoDeduccion
                            WHERE (DXM.IdPlanillaMensual = @idPlanillaMensual);
                        END

                        IF (
                            @esJueves = 1
                            AND @idSemanaNueva IS NOT NULL
                            AND NOT EXISTS (
                                SELECT
                                    1
                                FROM @eliminarEmpleado AS ED
                                WHERE (ED.Fecha = @fecha)
                                    AND (ED.ValorDocumento = @valorDocumento)
                            )
                        )
                        BEGIN
                            INSERT INTO dbo.PlanillaSemanal (
                                IdEmpleado
                                , IdSemana
                                , SalarioBruto
                                , TotalDeducciones
                                , SalarioNeto
                                , HorasOrdinarias
                                , HorasExtraNormal
                                , HorasExtraDoble
                            )
                            SELECT
                                @idEmpleado
                                , @idSemanaNueva
                                , 0
                                , 0
                                , 0
                                , 0
                                , 0
                                , 0
                            WHERE (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.PlanillaSemanal AS PS
                                WHERE (PS.IdEmpleado = @idEmpleado)
                                    AND (PS.IdSemana = @idSemanaNueva)
                            ));

                            SELECT
                                @idMesNuevo = S.IdMes
                            FROM dbo.Semana AS S
                            WHERE (S.Id = @idSemanaNueva);

                            INSERT INTO dbo.PlanillaMensual (
                                IdEmpleado
                                , IdMes
                                , SalarioBruto
                                , TotalDeducciones
                                , SalarioNeto
                            )
                            SELECT
                                @idEmpleado
                                , @idMesNuevo
                                , 0
                                , 0
                                , 0
                            WHERE (NOT EXISTS (
                                SELECT
                                    1
                                FROM dbo.PlanillaMensual AS PM
                                WHERE (PM.IdEmpleado = @idEmpleado)
                                    AND (PM.IdMes = @idMesNuevo)
                            ));

                            SELECT
                                @idPlanillaMensual = PM.Id
                            FROM dbo.PlanillaMensual AS PM
                            WHERE (PM.IdEmpleado = @idEmpleado)
                                AND (PM.IdMes = @idMesNuevo);

                            INSERT INTO dbo.DeduccionXMes (
                                IdPlanillaMensual
                                , IdTipoDeduccion
                                , MontoTotal
                            )
                            SELECT
                                @idPlanillaMensual
                                , DE.IdTipoDeduccion
                                , 0
                            FROM dbo.DeduccionEmpleado AS DE
                            WHERE (DE.IdEmpleado = @idEmpleado)
                                AND (DE.FechaInicio <= @fechaSiguiente)
                                AND (DE.FechaFin IS NULL OR DE.FechaFin > @fechaSiguiente)
                                AND (NOT EXISTS (
                                    SELECT
                                        1
                                    FROM dbo.DeduccionXMes AS DXM
                                    WHERE (DXM.IdPlanillaMensual = @idPlanillaMensual)
                                        AND (DXM.IdTipoDeduccion = DE.IdTipoDeduccion)
                                ));

                            SELECT
                                @jornada = AJ.Jornada
                                , @inicioSemana = AJ.InicioSemana
                            FROM @asignarJornada AS AJ
                            WHERE (AJ.Fecha = @fecha)
                                AND (AJ.ValorDocumento = @valorDocumento);

                            IF (@jornada IS NOT NULL)
                            BEGIN
                                SELECT
                                    @idTipoJornada = TJ.Id
                                FROM dbo.TipoJornada AS TJ
                                WHERE (TJ.Nombre = @jornada);

                                IF (@idTipoJornada IS NULL)
                                BEGIN
                                    THROW 51002, 'Tipo de jornada no existe en catalogo', 1;
                                END

                                INSERT INTO dbo.HorarioJornada (
                                    IdEmpleado
                                    , IdSemana
                                    , IdTipoJornada
                                )
                                SELECT
                                    @idEmpleado
                                    , @idSemanaNueva
                                    , @idTipoJornada
                                WHERE (@inicioSemana = @fechaSiguiente)
                                    AND (NOT EXISTS (
                                        SELECT
                                            1
                                        FROM dbo.HorarioJornada AS HJ
                                        WHERE (HJ.IdEmpleado = @idEmpleado)
                                            AND (HJ.IdSemana = @idSemanaNueva)
                                    ));

                                INSERT INTO dbo.BitacoraEvento (
                                    IdTipoEvento
                                    , IdUsuario
                                    , IP
                                    , Descripcion
                                )
                                SELECT
                                    @idTipoEventoJornada
                                    , @idUsuario
                                    , '127.0.0.1'
                                    , 'Asignacion de jornada para empleado: '
                                        + @valorDocumento
                                WHERE (@idTipoEventoJornada IS NOT NULL);
                            END
                        END

                        IF (EXISTS (
                            SELECT
                                1
                            FROM @eliminarEmpleado AS ED
                            WHERE (ED.Fecha = @fecha)
                                AND (ED.ValorDocumento = @valorDocumento)
                        ))
                        BEGIN
                            UPDATE E
                            SET
                                E.Activo = 0
                            FROM dbo.Empleado AS E
                            WHERE (E.Id = @idEmpleado);

                            UPDATE U
                            SET
                                U.Activo = 0
                            FROM dbo.Usuario AS U
                            WHERE (U.Id = @idUsuario);

                            INSERT INTO dbo.BitacoraEvento (
                                IdTipoEvento
                                , IdUsuario
                                , IP
                                , Descripcion
                            )
                            SELECT
                                @idTipoEventoEliminacion
                                , @idUsuario
                                , '127.0.0.1'
                                , 'Baja logica de empleado con documento: '
                                    + @valorDocumento
                            WHERE (@idTipoEventoEliminacion IS NOT NULL);
                        END
                    END

                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF (@@TRANCOUNT > 0)
                    BEGIN
                        ROLLBACK TRANSACTION;
                    END

                    SET @errorNumero = ERROR_NUMBER();
                    SET @errorMensaje = ERROR_MESSAGE();
                    SET @errorProcedimiento = ISNULL(ERROR_PROCEDURE(), 'sp_procesar_operaciones_xml');
                    SET @errorLinea = ERROR_LINE();

                    INSERT INTO dbo.DBError (
                        Mensaje
                        , Severidad
                        , Estado
                    )
                    VALUES (
                        'Empleado '
                            + ISNULL(@valorDocumento, '')
                            + ': '
                            + ISNULL(@errorMensaje, '')
                            + ' | Numero: '
                            + CAST(ISNULL(@errorNumero, 0) AS VARCHAR(20))
                            + ' | Procedimiento: '
                            + ISNULL(@errorProcedimiento, '')
                            + ' | Linea: '
                            + CAST(ISNULL(@errorLinea, 0) AS VARCHAR(20))
                        , ERROR_SEVERITY()
                        , ERROR_STATE()
                    );

                    IF (@outResultCode = 0)
                    BEGIN
                        SET @outResultCode = CASE
                            WHEN (ISNULL(@errorNumero, 0) > 50000) THEN @errorNumero
                            ELSE 50008
                        END;
                    END
                END CATCH

                SET @numeroEmpleado = @numeroEmpleado + 1;
            END

            SET @numeroFecha = @numeroFecha + 1;
        END
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Mensaje
            , Severidad
            , Estado
        )
        VALUES (
            ERROR_MESSAGE()
            , ERROR_SEVERITY()
            , ERROR_STATE()
        );

        SET @outResultCode = CASE
            WHEN (ERROR_NUMBER() > 50000) THEN ERROR_NUMBER()
            ELSE 50008
        END;
    END CATCH
END
GO
