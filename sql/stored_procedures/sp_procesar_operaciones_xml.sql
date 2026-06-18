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
    DECLARE @idTipoDocumento INT;
    DECLARE @idTipoEventoEliminacion INT;
    DECLARE @idTipoEventoUpdate INT;

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

    DECLARE @mesNecesario TABLE (
        FechaInicio DATE NOT NULL PRIMARY KEY
        , FechaFin DATE NOT NULL
        , NumJueves TINYINT NOT NULL
    );

    DECLARE @semanaNecesaria TABLE (
        FechaInicio DATE NOT NULL PRIMARY KEY
        , FechaFin DATE NOT NULL
    );

    DECLARE @marcaCalculada TABLE (
        IdEmpleado INT NOT NULL
        , IdHorarioJornada INT NOT NULL
        , IdSemana INT NOT NULL
        , Fecha DATE NOT NULL
        , HoraEntrada DATETIME NOT NULL
        , HoraSalida DATETIME NOT NULL
        , SalarioXHora DECIMAL(14,2) NOT NULL
        , HorasOrdinarias DECIMAL(8,2) NOT NULL
        , HorasExtraNormal DECIMAL(8,2) NOT NULL
        , HorasExtraDoble DECIMAL(8,2) NOT NULL
        , MontoOrdinario DECIMAL(14,2) NOT NULL
        , MontoExtraNormal DECIMAL(14,2) NOT NULL
        , MontoExtraDoble DECIMAL(14,2) NOT NULL
    );

    DECLARE @deduccionCalculada TABLE (
        IdPlanillaSemanal INT NOT NULL
        , IdMarcaAsistencia INT NOT NULL
        , IdTipoMovimiento INT NOT NULL
        , Monto DECIMAL(14,2) NOT NULL
    );

    DECLARE @juevesCierre TABLE (
        Fecha DATE NOT NULL
        , ValorDocumento VARCHAR(50) NOT NULL
    );

    DECLARE @fechaCierre TABLE (
        Fecha DATE NOT NULL PRIMARY KEY
    );

    SET @outResultCode = 0;

    SELECT TOP (1)
        @idDepartamento = D.Id
    FROM dbo.Departamento AS D
    ORDER BY
        D.Id ASC;

    SELECT TOP (1)
        @idTipoDocumento = TD.Id
    FROM dbo.TipoDocIdentidad AS TD
    ORDER BY
        TD.Id ASC;

    SELECT TOP (1)
        @idTipoEventoEliminacion = TE.Id
    FROM dbo.TipoEvento AS TE
    WHERE (TE.Nombre = 'Eliminar empleado')
    ORDER BY
        TE.Id ASC;

    SELECT TOP (1)
        @idTipoEventoUpdate = TE.Id
    FROM dbo.TipoEvento AS TE
    WHERE (TE.Nombre = 'Update exitoso')
    ORDER BY
        TE.Id ASC;

    IF (@idTipoEventoEliminacion IS NULL)
    BEGIN
        SELECT TOP (1)
            @idTipoEventoEliminacion = TE.Id
        FROM dbo.TipoEvento AS TE
        ORDER BY
            TE.Id ASC;
    END

    IF (@idTipoEventoUpdate IS NULL)
    BEGIN
        SELECT TOP (1)
            @idTipoEventoUpdate = TE.Id
        FROM dbo.TipoEvento AS TE
        ORDER BY
            TE.Id ASC;
    END

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
            , F.FechaOperacion.value('@Fecha', 'DATE')
        ) AS InicioSemana
    FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS F(FechaOperacion)
    CROSS APPLY F.FechaOperacion.nodes('AsignarJornada') AS X(Operacion);

    INSERT INTO @juevesCierre (
        Fecha
        , ValorDocumento
    )
    SELECT
        O.Fecha
        , O.ValorDocumento
    FROM (
        SELECT
            IE.Fecha
            , IE.ValorDocumento
        FROM @insertarEmpleado AS IE
        UNION
        SELECT
            ED.Fecha
            , ED.ValorDocumento
        FROM @eliminarEmpleado AS ED
        UNION
        SELECT
            AD.Fecha
            , AD.ValorDocumento
        FROM @asociaDeduccion AS AD
        UNION
        SELECT
            DD.Fecha
            , DD.ValorDocumento
        FROM @desasociaDeduccion AS DD
        UNION
        SELECT
            MA.FechaOperacion
            , MA.ValorDocumento
        FROM @marcaAsistencia AS MA
        UNION
        SELECT
            AJ.Fecha
            , AJ.ValorDocumento
        FROM @asignarJornada AS AJ
    ) AS O
    WHERE (DATEDIFF(DAY, '19000104', O.Fecha) % 7 = 0);

    INSERT INTO @fechaCierre (
        Fecha
    )
    SELECT DISTINCT
        JC.Fecha
    FROM @juevesCierre AS JC;

    WITH N AS (
        SELECT
            V.N
        FROM (
            VALUES
                (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
                , (10), (11), (12), (13), (14), (15), (16), (17), (18), (19)
                , (20), (21), (22), (23), (24), (25), (26), (27), (28), (29)
                , (30), (31), (32), (33), (34), (35), (36), (37)
        ) AS V(N)
    ),
    BaseMes AS (
        SELECT DISTINCT
            AJ.InicioSemana AS FechaInicio
        FROM @asignarJornada AS AJ
        WHERE (DATEPART(DAY, AJ.InicioSemana) <= 7)
        UNION
        SELECT DISTINCT
            DATEADD(DAY, 1, FC.Fecha) AS FechaInicio
        FROM @fechaCierre AS FC
        WHERE (DATEPART(DAY, DATEADD(DAY, 1, FC.Fecha)) <= 7)
    ),
    MesCalculado AS (
        SELECT
            BM.FechaInicio
            , DATEADD(DAY, -1, NF.PrimerViernesSiguiente) AS FechaFin
        FROM BaseMes AS BM
        CROSS APPLY (
            SELECT
                DATEFROMPARTS(
                    YEAR(DATEADD(MONTH, 1, BM.FechaInicio))
                    , MONTH(DATEADD(MONTH, 1, BM.FechaInicio))
                    , 1
                ) AS PrimerDiaMesSiguiente
        ) AS MS
        CROSS APPLY (
            SELECT TOP (1)
                DATEADD(DAY, N.N, MS.PrimerDiaMesSiguiente) AS PrimerViernesSiguiente
            FROM N AS N
            WHERE (N.N BETWEEN 0 AND 6)
                AND (
                    DATEDIFF(DAY, '19000105', DATEADD(DAY, N.N, MS.PrimerDiaMesSiguiente)) % 7 = 0
                )
            ORDER BY
                N.N ASC
        ) AS NF
    )
    INSERT INTO @mesNecesario (
        FechaInicio
        , FechaFin
        , NumJueves
    )
    SELECT
        MC.FechaInicio
        , MC.FechaFin
        , COUNT(N.N) AS NumJueves
    FROM MesCalculado AS MC
    INNER JOIN N AS N
        ON DATEADD(DAY, N.N, MC.FechaInicio) <= MC.FechaFin
        AND DATEDIFF(DAY, '19000104', DATEADD(DAY, N.N, MC.FechaInicio)) % 7 = 0
    GROUP BY
        MC.FechaInicio
        , MC.FechaFin;

    INSERT INTO @semanaNecesaria (
        FechaInicio
        , FechaFin
    )
    SELECT DISTINCT
        AJ.InicioSemana
        , DATEADD(DAY, 6, AJ.InicioSemana)
    FROM @asignarJornada AS AJ
    UNION
    SELECT DISTINCT
        DATEADD(DAY, 1, FC.Fecha)
        , DATEADD(DAY, 7, FC.Fecha)
    FROM @fechaCierre AS FC
    WHERE (DATEPART(DAY, DATEADD(DAY, 1, FC.Fecha)) <= 7);

    IF (
        @idDepartamento IS NULL
        OR @idTipoDocumento IS NULL
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Usuario (
            Username
            , PasswordHash
            , Tipo
        )
        SELECT
            ISNULL(NULLIF(IE.Username, ''), IE.ValorDocumento)
            , ISNULL(NULLIF(IE.PasswordHash, ''), IE.ValorDocumento)
            , 'empleado'
        FROM @insertarEmpleado AS IE
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Usuario AS U
            WHERE (U.Username = ISNULL(NULLIF(IE.Username, ''), IE.ValorDocumento))
        ));

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
        SELECT
            P.Id
            , @idDepartamento
            , @idTipoDocumento
            , U.Id
            , IE.ValorDocumento
            , IE.Nombre
            , ISNULL(NULLIF(IE.CuentaBancaria, ''), IE.ValorDocumento)
            , IE.FechaContratacion
            , 1
        FROM @insertarEmpleado AS IE
        INNER JOIN dbo.Puesto AS P
            ON P.Nombre = IE.Puesto
        INNER JOIN dbo.Usuario AS U
            ON U.Username = ISNULL(NULLIF(IE.Username, ''), IE.ValorDocumento)
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Empleado AS E
            WHERE (E.ValorDocumento = IE.ValorDocumento)
                OR (E.Nombre = IE.Nombre)
        ));

        INSERT INTO dbo.Mes (
            FechaInicio
            , FechaFin
            , NumJueves
        )
        SELECT
            MN.FechaInicio
            , MN.FechaFin
            , CASE
                WHEN (MN.NumJueves = 0) THEN 1
                ELSE MN.NumJueves
            END
        FROM @mesNecesario AS MN
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Mes AS M
            WHERE (M.FechaInicio = MN.FechaInicio)
                AND (M.FechaFin = MN.FechaFin)
        ));

        INSERT INTO dbo.Semana (
            IdMes
            , FechaInicio
            , FechaFin
        )
        SELECT
            SM.IdMes
            , SN.FechaInicio
            , SN.FechaFin
        FROM @semanaNecesaria AS SN
        CROSS APPLY (
            SELECT TOP (1)
                M.Id AS IdMes
            FROM dbo.Mes AS M
            WHERE (SN.FechaInicio BETWEEN M.FechaInicio AND M.FechaFin)
            ORDER BY
                CASE
                    WHEN (M.FechaInicio = SN.FechaInicio) THEN 0
                    ELSE 1
                END ASC
                , M.FechaInicio DESC
                , M.Id DESC
        ) AS SM
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Semana AS S
            WHERE (S.FechaInicio = SN.FechaInicio)
        ));

        INSERT INTO dbo.HorarioJornada (
            IdEmpleado
            , IdSemana
            , IdTipoJornada
        )
        SELECT
            E.Id
            , S.Id
            , TJ.Id
        FROM @asignarJornada AS AJ
        INNER JOIN dbo.Empleado AS E
            ON E.ValorDocumento = AJ.ValorDocumento
        INNER JOIN dbo.Semana AS S
            ON S.FechaInicio = AJ.InicioSemana
        INNER JOIN dbo.TipoJornada AS TJ
            ON TJ.Nombre = AJ.Jornada
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM @eliminarEmpleado AS ED
            WHERE (ED.ValorDocumento = AJ.ValorDocumento)
                AND (ED.Fecha <= AJ.Fecha)
        ))
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.HorarioJornada AS HJ
                WHERE (HJ.IdEmpleado = E.Id)
                    AND (HJ.IdSemana = S.Id)
            ));

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
            HJ.IdEmpleado
            , HJ.IdSemana
            , 0
            , 0
            , 0
            , 0
            , 0
            , 0
        FROM dbo.HorarioJornada AS HJ
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.PlanillaSemanal AS PS
            WHERE (PS.IdEmpleado = HJ.IdEmpleado)
                AND (PS.IdSemana = HJ.IdSemana)
        ));

        INSERT INTO dbo.DeduccionEmpleado (
            IdEmpleado
            , IdTipoDeduccion
            , MontoFijo
            , FechaInicio
            , FechaFin
        )
        SELECT
            E.Id
            , TD.Id
            , AD.MontoFijo
            , AD.Fecha
            , NULL
        FROM @asociaDeduccion AS AD
        INNER JOIN dbo.Empleado AS E
            ON E.ValorDocumento = AD.ValorDocumento
        INNER JOIN dbo.TipoDeduccion AS TD
            ON TD.Nombre = AD.TipoDeduccion
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM @eliminarEmpleado AS ED
            WHERE (ED.ValorDocumento = AD.ValorDocumento)
                AND (ED.Fecha <= AD.Fecha)
        ))
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.DeduccionEmpleado AS DE
                WHERE (DE.IdEmpleado = E.Id)
                    AND (DE.IdTipoDeduccion = TD.Id)
                    AND (DE.FechaFin IS NULL)
            ));

        UPDATE DE
        SET
            DE.FechaFin = DD.Fecha
        FROM dbo.DeduccionEmpleado AS DE
        INNER JOIN dbo.Empleado AS E
            ON E.Id = DE.IdEmpleado
        INNER JOIN @desasociaDeduccion AS DD
            ON DD.ValorDocumento = E.ValorDocumento
        INNER JOIN dbo.TipoDeduccion AS TD
            ON TD.Id = DE.IdTipoDeduccion
            AND TD.Nombre = DD.TipoDeduccion
        WHERE (DE.FechaFin IS NULL);

        INSERT INTO @marcaCalculada (
            IdEmpleado
            , IdHorarioJornada
            , IdSemana
            , Fecha
            , HoraEntrada
            , HoraSalida
            , SalarioXHora
            , HorasOrdinarias
            , HorasExtraNormal
            , HorasExtraDoble
            , MontoOrdinario
            , MontoExtraNormal
            , MontoExtraDoble
        )
        SELECT
            E.Id
            , HJ.Id
            , HJ.IdSemana
            , CAST(MA.HoraEntrada AS DATE)
            , MA.HoraEntrada
            , MA.HoraSalida
            , CAST(P.SalarioXHora AS DECIMAL(14,2))
            , HC.HorasOrdinarias
            , HC.HorasExtraNormal
            , HC.HorasExtraDoble
            , HC.HorasOrdinarias * CAST(P.SalarioXHora AS DECIMAL(14,2))
            , HC.HorasExtraNormal * CAST(P.SalarioXHora AS DECIMAL(14,2)) * 1.5
            , HC.HorasExtraDoble * CAST(P.SalarioXHora AS DECIMAL(14,2)) * 2.0
        FROM @marcaAsistencia AS MA
        INNER JOIN dbo.Empleado AS E
            ON E.ValorDocumento = MA.ValorDocumento
        INNER JOIN dbo.Puesto AS P
            ON P.Id = E.IdPuesto
        INNER JOIN dbo.HorarioJornada AS HJ
            ON HJ.IdEmpleado = E.Id
        INNER JOIN dbo.Semana AS S
            ON S.Id = HJ.IdSemana
            AND CAST(MA.HoraEntrada AS DATE) BETWEEN S.FechaInicio AND S.FechaFin
        INNER JOIN dbo.TipoJornada AS TJ
            ON TJ.Id = HJ.IdTipoJornada
        CROSS APPLY (
            SELECT
                DATEDIFF(MINUTE, MA.HoraEntrada, MA.HoraSalida) / 60 AS TotalHoras
                , CASE
                    WHEN DATEDIFF(
                        MINUTE
                        , MA.HoraEntrada
                        , CASE
                            WHEN MA.HoraSalida > CA.FinJornada THEN CA.FinJornada
                            ELSE MA.HoraSalida
                        END
                    ) < 0 THEN 0
                    ELSE DATEDIFF(
                        MINUTE
                        , MA.HoraEntrada
                        , CASE
                            WHEN MA.HoraSalida > CA.FinJornada THEN CA.FinJornada
                            ELSE MA.HoraSalida
                        END
                    ) / 60
                END AS HorasOrdinariasBase
            FROM (
                SELECT
                    CASE
                        WHEN (CAST(TJ.HoraFin AS TIME) < CAST(MA.HoraEntrada AS TIME))
                            THEN DATEADD(
                                DAY
                                , 1
                                , DATEADD(
                                    SECOND
                                    , DATEDIFF(SECOND, CAST('00:00:00' AS TIME), TJ.HoraFin)
                                    , CAST(CAST(MA.HoraEntrada AS DATE) AS DATETIME)
                                )
                            )
                        ELSE DATEADD(
                            SECOND
                            , DATEDIFF(SECOND, CAST('00:00:00' AS TIME), TJ.HoraFin)
                            , CAST(CAST(MA.HoraEntrada AS DATE) AS DATETIME)
                        )
                    END AS FinJornada
            ) AS CA
        ) AS HB
        CROSS APPLY (
            SELECT
                CASE
                    WHEN (HB.HorasOrdinariasBase > HB.TotalHoras) THEN HB.TotalHoras
                    ELSE HB.HorasOrdinariasBase
                END AS HorasOrdinarias
                , CASE
                    WHEN (DATEDIFF(DAY, '19000107', CAST(MA.HoraEntrada AS DATE)) % 7 = 0)
                        OR (EXISTS (
                            SELECT
                                1
                            FROM dbo.Feriado AS F
                            WHERE (F.Fecha = CAST(MA.HoraEntrada AS DATE))
                        ))
                        THEN 0
                    WHEN (HB.TotalHoras - HB.HorasOrdinariasBase < 0) THEN 0
                    ELSE HB.TotalHoras - HB.HorasOrdinariasBase
                END AS HorasExtraNormal
                , CASE
                    WHEN (DATEDIFF(DAY, '19000107', CAST(MA.HoraEntrada AS DATE)) % 7 = 0)
                        OR (EXISTS (
                            SELECT
                                1
                            FROM dbo.Feriado AS F
                            WHERE (F.Fecha = CAST(MA.HoraEntrada AS DATE))
                        ))
                        THEN CASE
                            WHEN (HB.TotalHoras - HB.HorasOrdinariasBase < 0) THEN 0
                            ELSE HB.TotalHoras - HB.HorasOrdinariasBase
                        END
                    ELSE 0
                END AS HorasExtraDoble
        ) AS HC
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM @eliminarEmpleado AS ED
            WHERE (ED.ValorDocumento = MA.ValorDocumento)
                AND (ED.Fecha <= MA.FechaOperacion)
        ))
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MarcaAsistencia AS MX
                WHERE (MX.IdEmpleado = E.Id)
                    AND (MX.Fecha = CAST(MA.HoraEntrada AS DATE))
            ));

        INSERT INTO dbo.MarcaAsistencia (
            IdEmpleado
            , IdHorarioJornada
            , Fecha
            , HoraEntrada
            , HoraSalida
        )
        SELECT
            MC.IdEmpleado
            , MC.IdHorarioJornada
            , MC.Fecha
            , MC.HoraEntrada
            , MC.HoraSalida
        FROM @marcaCalculada AS MC
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.MarcaAsistencia AS MA
            WHERE (MA.IdEmpleado = MC.IdEmpleado)
                AND (MA.Fecha = MC.Fecha)
        ));

        INSERT INTO dbo.MovimientoAsistencia (
            IdMarcaAsistencia
            , IdTipoMovimiento
            , CantidadHoras
            , Monto
        )
        SELECT
            MA.Id
            , 1
            , MC.HorasOrdinarias
            , MC.MontoOrdinario
        FROM @marcaCalculada AS MC
        INNER JOIN dbo.MarcaAsistencia AS MA
            ON MA.IdEmpleado = MC.IdEmpleado
            AND MA.Fecha = MC.Fecha
        WHERE (MC.HorasOrdinarias > 0)
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MovimientoAsistencia AS MV
                WHERE (MV.IdMarcaAsistencia = MA.Id)
                    AND (MV.IdTipoMovimiento = 1)
            ));

        INSERT INTO dbo.MovimientoAsistencia (
            IdMarcaAsistencia
            , IdTipoMovimiento
            , CantidadHoras
            , Monto
        )
        SELECT
            MA.Id
            , 2
            , MC.HorasExtraNormal
            , MC.MontoExtraNormal
        FROM @marcaCalculada AS MC
        INNER JOIN dbo.MarcaAsistencia AS MA
            ON MA.IdEmpleado = MC.IdEmpleado
            AND MA.Fecha = MC.Fecha
        WHERE (MC.HorasExtraNormal > 0)
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MovimientoAsistencia AS MV
                WHERE (MV.IdMarcaAsistencia = MA.Id)
                    AND (MV.IdTipoMovimiento = 2)
            ));

        INSERT INTO dbo.MovimientoAsistencia (
            IdMarcaAsistencia
            , IdTipoMovimiento
            , CantidadHoras
            , Monto
        )
        SELECT
            MA.Id
            , 3
            , MC.HorasExtraDoble
            , MC.MontoExtraDoble
        FROM @marcaCalculada AS MC
        INNER JOIN dbo.MarcaAsistencia AS MA
            ON MA.IdEmpleado = MC.IdEmpleado
            AND MA.Fecha = MC.Fecha
        WHERE (MC.HorasExtraDoble > 0)
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MovimientoAsistencia AS MV
                WHERE (MV.IdMarcaAsistencia = MA.Id)
                    AND (MV.IdTipoMovimiento = 3)
            ));

        UPDATE PS
        SET
            PS.SalarioBruto = PS.SalarioBruto + MN.SalarioBruto
            , PS.HorasOrdinarias = PS.HorasOrdinarias + MN.HorasOrdinarias
            , PS.HorasExtraNormal = PS.HorasExtraNormal + MN.HorasExtraNormal
            , PS.HorasExtraDoble = PS.HorasExtraDoble + MN.HorasExtraDoble
        FROM dbo.PlanillaSemanal AS PS
        INNER JOIN (
            SELECT
                MC.IdEmpleado
                , MC.IdSemana
                , SUM(MC.MontoOrdinario + MC.MontoExtraNormal + MC.MontoExtraDoble) AS SalarioBruto
                , SUM(MC.HorasOrdinarias)
                    AS HorasOrdinarias
                , SUM(MC.HorasExtraNormal)
                    AS HorasExtraNormal
                , SUM(MC.HorasExtraDoble)
                    AS HorasExtraDoble
            FROM @marcaCalculada AS MC
            GROUP BY
                MC.IdEmpleado
                , MC.IdSemana
        ) AS MN
            ON MN.IdEmpleado = PS.IdEmpleado
            AND MN.IdSemana = PS.IdSemana;

        WITH MarcaDeduccion AS (
            SELECT
                PS.Id AS IdPlanillaSemanal
                , PS.IdEmpleado
                , PS.SalarioBruto
                , JC.Fecha AS FechaCierre
                , S.FechaInicio
                , S.FechaFin
                , M.NumJueves
                , MA.Id AS IdMarcaAsistencia
                , ROW_NUMBER() OVER (
                    PARTITION BY PS.Id
                    ORDER BY MA.Fecha DESC, MA.Id DESC
                ) AS NumeroFila
            FROM dbo.PlanillaSemanal AS PS
            INNER JOIN dbo.Semana AS S
                ON S.Id = PS.IdSemana
            INNER JOIN dbo.Mes AS M
                ON M.Id = S.IdMes
            INNER JOIN dbo.Empleado AS E
                ON E.Id = PS.IdEmpleado
            INNER JOIN @juevesCierre AS JC
                ON JC.ValorDocumento = E.ValorDocumento
                AND JC.Fecha BETWEEN S.FechaInicio AND S.FechaFin
            INNER JOIN dbo.MarcaAsistencia AS MA
                ON MA.IdEmpleado = PS.IdEmpleado
                AND MA.Fecha BETWEEN S.FechaInicio AND S.FechaFin
        )
        INSERT INTO @deduccionCalculada (
            IdPlanillaSemanal
            , IdMarcaAsistencia
            , IdTipoMovimiento
            , Monto
        )
        SELECT
            MD.IdPlanillaSemanal
            , MD.IdMarcaAsistencia
            , TD.IdTipoMovimiento
            , MD.SalarioBruto * TD.Valor
        FROM MarcaDeduccion AS MD
        INNER JOIN dbo.DeduccionEmpleado AS DE
            ON DE.IdEmpleado = MD.IdEmpleado
        INNER JOIN dbo.TipoDeduccion AS TD
            ON TD.Id = DE.IdTipoDeduccion
        WHERE (MD.NumeroFila = 1)
            AND (TD.EsPorcentual = 1)
            AND (DE.FechaInicio <= MD.FechaCierre)
            AND (DE.FechaFin IS NULL OR DE.FechaFin > MD.FechaCierre)
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MovimientoAsistencia AS MV
                WHERE (MV.IdMarcaAsistencia = MD.IdMarcaAsistencia)
                    AND (MV.IdTipoMovimiento = TD.IdTipoMovimiento)
                    AND (MV.CantidadHoras = 0)
            ))
        UNION ALL
        SELECT
            MD.IdPlanillaSemanal
            , MD.IdMarcaAsistencia
            , TD.IdTipoMovimiento
            , DE.MontoFijo / NULLIF(MD.NumJueves, 0)
        FROM MarcaDeduccion AS MD
        INNER JOIN dbo.DeduccionEmpleado AS DE
            ON DE.IdEmpleado = MD.IdEmpleado
        INNER JOIN dbo.TipoDeduccion AS TD
            ON TD.Id = DE.IdTipoDeduccion
        WHERE (MD.NumeroFila = 1)
            AND (TD.EsPorcentual = 0)
            AND (DE.FechaInicio <= MD.FechaCierre)
            AND (DE.FechaFin IS NULL OR DE.FechaFin > MD.FechaCierre)
            AND (NOT EXISTS (
                SELECT
                    1
                FROM dbo.MovimientoAsistencia AS MV
                WHERE (MV.IdMarcaAsistencia = MD.IdMarcaAsistencia)
                    AND (MV.IdTipoMovimiento = TD.IdTipoMovimiento)
                    AND (MV.CantidadHoras = 0)
            ));

        INSERT INTO dbo.MovimientoAsistencia (
            IdMarcaAsistencia
            , IdTipoMovimiento
            , CantidadHoras
            , Monto
        )
        SELECT
            DC.IdMarcaAsistencia
            , DC.IdTipoMovimiento
            , 0
            , DC.Monto
        FROM @deduccionCalculada AS DC
        WHERE (DC.Monto > 0);

        UPDATE PS
        SET
            PS.TotalDeducciones = PS.TotalDeducciones + DC.TotalDeducciones
        FROM dbo.PlanillaSemanal AS PS
        INNER JOIN (
            SELECT
                DC.IdPlanillaSemanal
                , SUM(DC.Monto) AS TotalDeducciones
            FROM @deduccionCalculada AS DC
            WHERE (DC.Monto > 0)
            GROUP BY
                DC.IdPlanillaSemanal
        ) AS DC
            ON DC.IdPlanillaSemanal = PS.Id;

        UPDATE PS
        SET
            PS.SalarioNeto = PS.SalarioBruto - PS.TotalDeducciones
        FROM dbo.PlanillaSemanal AS PS;

        INSERT INTO dbo.PlanillaMensual (
            IdEmpleado
            , IdMes
            , SalarioBruto
            , TotalDeducciones
            , SalarioNeto
        )
        SELECT DISTINCT
            PS.IdEmpleado
            , S.IdMes
            , 0
            , 0
            , 0
        FROM dbo.PlanillaSemanal AS PS
        INNER JOIN dbo.Semana AS S
            ON S.Id = PS.IdSemana
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.PlanillaMensual AS PM
            WHERE (PM.IdEmpleado = PS.IdEmpleado)
                AND (PM.IdMes = S.IdMes)
        ));

        UPDATE PM
        SET
            PM.SalarioBruto = ISNULL(T.SalarioBruto, 0)
            , PM.TotalDeducciones = ISNULL(T.TotalDeducciones, 0)
            , PM.SalarioNeto = ISNULL(T.SalarioNeto, 0)
        FROM dbo.PlanillaMensual AS PM
        OUTER APPLY (
            SELECT
                SUM(PS.SalarioBruto) AS SalarioBruto
                , SUM(PS.TotalDeducciones) AS TotalDeducciones
                , SUM(PS.SalarioNeto) AS SalarioNeto
            FROM dbo.PlanillaSemanal AS PS
            INNER JOIN dbo.Semana AS S
                ON S.Id = PS.IdSemana
            WHERE (PS.IdEmpleado = PM.IdEmpleado)
                AND (S.IdMes = PM.IdMes)
        ) AS T;

        DELETE DXM
        FROM dbo.DeduccionXMes AS DXM
        INNER JOIN dbo.PlanillaMensual AS PM
            ON PM.Id = DXM.IdPlanillaMensual;

        INSERT INTO dbo.DeduccionXMes (
            IdPlanillaMensual
            , IdTipoDeduccion
            , MontoTotal
        )
        SELECT
            PM.Id
            , TD.Id
            , SUM(MV.Monto)
        FROM dbo.PlanillaMensual AS PM
        INNER JOIN dbo.Mes AS M
            ON M.Id = PM.IdMes
        INNER JOIN dbo.MarcaAsistencia AS MA
            ON MA.IdEmpleado = PM.IdEmpleado
            AND MA.Fecha BETWEEN M.FechaInicio AND M.FechaFin
        INNER JOIN dbo.MovimientoAsistencia AS MV
            ON MV.IdMarcaAsistencia = MA.Id
        INNER JOIN dbo.TipoDeduccion AS TD
            ON TD.IdTipoMovimiento = MV.IdTipoMovimiento
        GROUP BY
            PM.Id
            , TD.Id
        HAVING (SUM(MV.Monto) > 0);

        UPDATE E
        SET
            E.Activo = 0
        FROM dbo.Empleado AS E
        INNER JOIN @eliminarEmpleado AS ED
            ON ED.ValorDocumento = E.ValorDocumento;

        UPDATE U
        SET
            U.Activo = 0
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Empleado AS E
            ON E.IdUsuario = U.Id
        INNER JOIN @eliminarEmpleado AS ED
            ON ED.ValorDocumento = E.ValorDocumento;

        INSERT INTO dbo.BitacoraEvento (
            IdTipoEvento
            , IdUsuario
            , IP
            , Descripcion
        )
        SELECT
            @idTipoEventoEliminacion
            , E.IdUsuario
            , '127.0.0.1'
            , 'Baja logica de empleado con documento: ' + E.ValorDocumento
        FROM dbo.Empleado AS E
        INNER JOIN @eliminarEmpleado AS ED
            ON ED.ValorDocumento = E.ValorDocumento
        WHERE (@idTipoEventoEliminacion IS NOT NULL);

        COMMIT TRANSACTION;

        SET @outResultCode = 0;
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

        SET @outResultCode = 50008;
    END CATCH
END
GO
