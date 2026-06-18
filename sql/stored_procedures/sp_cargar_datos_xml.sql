USE PlanillaObrera;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_cargar_datos_xml', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_cargar_datos_xml;
END
GO

CREATE PROCEDURE dbo.sp_cargar_datos_xml
    @inXmlData XML
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tipoDocumento TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
    );

    DECLARE @departamento TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
    );

    DECLARE @tipoEvento TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
    );

    DECLARE @feriado TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(150) NOT NULL
        , Fecha DATE NOT NULL
    );

    DECLARE @tipoMovimiento TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
        , Accion CHAR(1) NOT NULL
    );

    DECLARE @tipoDeduccion TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
        , EsObligatoria BIT NOT NULL
        , EsPorcentual BIT NOT NULL
        , Valor DECIMAL(10,4) NOT NULL
        , TipoMovimiento VARCHAR(100) NOT NULL
    );

    DECLARE @puesto TABLE (
        Nombre VARCHAR(100) NOT NULL PRIMARY KEY
        , SalarioXHora MONEY NOT NULL
    );

    DECLARE @tipoJornada TABLE (
        Id INT NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
        , HoraInicio TIME NOT NULL
        , HoraFin TIME NOT NULL
    );

    DECLARE @usuario TABLE (
        Username VARCHAR(100) NOT NULL PRIMARY KEY
        , PasswordHash VARCHAR(256) NOT NULL
        , Tipo VARCHAR(50) NOT NULL
    );

    DECLARE @empleado TABLE (
        ValorDocumento VARCHAR(50) NOT NULL PRIMARY KEY
        , Nombre VARCHAR(100) NOT NULL
        , Puesto VARCHAR(100) NOT NULL
        , FechaContratacion DATE NOT NULL
    );

    DECLARE @movimientoHistorico TABLE (
        ValorDocumento VARCHAR(50) NOT NULL
        , TipoMovimiento VARCHAR(100) NOT NULL
        , Fecha DATE NOT NULL
        , Monto DECIMAL(14,2) NOT NULL
    );

    SET @outResultCode = 0;

    INSERT INTO @tipoDocumento (
        Id
        , Nombre
    )
    VALUES (
        1
        , 'Cedula'
    );

    INSERT INTO @departamento (
        Id
        , Nombre
    )
    VALUES (
        1
        , 'Produccion y Operaciones'
    );

    INSERT INTO @tipoEvento (
        Id
        , Nombre
    )
    SELECT
        X.Item.value('@Id', 'INT') AS Id
        , X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
    FROM @inXmlData.nodes('/Datos/TiposEvento/TipoEvento') AS X(Item);

    INSERT INTO @feriado (
        Id
        , Nombre
        , Fecha
    )
    SELECT
        X.Item.value('@Id', 'INT') AS Id
        , X.Item.value('@Nombre', 'VARCHAR(150)') AS Nombre
        , X.Item.value('@Fecha', 'DATE') AS Fecha
    FROM @inXmlData.nodes('/Datos/Feriados/Feriado') AS X(Item);

    INSERT INTO @tipoMovimiento (
        Id
        , Nombre
        , Accion
    )
    SELECT
        X.Item.value('@Id', 'INT') AS Id
        , X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
        , CASE X.Item.value('@TipoAccion', 'VARCHAR(50)')
            WHEN 'Credito' THEN '+'
            WHEN 'Debito' THEN '-'
            WHEN '+' THEN '+'
            WHEN '-' THEN '-'
            ELSE '+'
        END AS Accion
    FROM @inXmlData.nodes('/Datos/TiposMovimientos/TipoMovimiento') AS X(Item);

    INSERT INTO @tipoDeduccion (
        Id
        , Nombre
        , EsObligatoria
        , EsPorcentual
        , Valor
        , TipoMovimiento
    )
    SELECT
        X.Item.value('@Id', 'INT') AS Id
        , X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
        , ISNULL(X.Item.value('@EsObligatoria', 'BIT'), 0) AS EsObligatoria
        , ISNULL(X.Item.value('@EsPorcentual', 'BIT'), 0) AS EsPorcentual
        , ISNULL(X.Item.value('@Valor', 'DECIMAL(10,4)'), 0) AS Valor
        , X.Item.value('@TipoMovimiento', 'VARCHAR(100)') AS TipoMovimiento
    FROM @inXmlData.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS X(Item);

    INSERT INTO @puesto (
        Nombre
        , SalarioXHora
    )
    SELECT
        X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
        , X.Item.value('@SalarioxHora', 'MONEY') AS SalarioXHora
    FROM @inXmlData.nodes('/Datos/Puestos/Puesto') AS X(Item);

    INSERT INTO @tipoJornada (
        Id
        , Nombre
        , HoraInicio
        , HoraFin
    )
    SELECT
        X.Item.value('@Id', 'INT') AS Id
        , X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
        , X.Item.value('@HoraInicio', 'TIME') AS HoraInicio
        , X.Item.value('@HoraFin', 'TIME') AS HoraFin
    FROM @inXmlData.nodes('/Datos/TiposJornada/TipoJornada') AS X(Item);

    INSERT INTO @usuario (
        Username
        , PasswordHash
        , Tipo
    )
    SELECT
        X.Item.value('@Nombre', 'VARCHAR(100)') AS Username
        , X.Item.value('@Pass', 'VARCHAR(256)') AS PasswordHash
        , CASE X.Item.value('@Id', 'INT')
            WHEN 1 THEN 'administrador'
            ELSE 'empleado'
        END AS Tipo
    FROM @inXmlData.nodes('/Datos/Usuarios/usuario') AS X(Item);

    INSERT INTO @empleado (
        ValorDocumento
        , Nombre
        , Puesto
        , FechaContratacion
    )
    SELECT
        X.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(50)') AS ValorDocumento
        , X.Item.value('@Nombre', 'VARCHAR(100)') AS Nombre
        , X.Item.value('@Puesto', 'VARCHAR(100)') AS Puesto
        , X.Item.value('@FechaContratacion', 'DATE') AS FechaContratacion
    FROM @inXmlData.nodes('/Datos/Empleados/empleado') AS X(Item);

    INSERT INTO @movimientoHistorico (
        ValorDocumento
        , TipoMovimiento
        , Fecha
        , Monto
    )
    SELECT
        X.Item.value('@ValorDocId', 'VARCHAR(50)') AS ValorDocumento
        , X.Item.value('@IdTipoMovimiento', 'VARCHAR(100)') AS TipoMovimiento
        , X.Item.value('@Fecha', 'DATE') AS Fecha
        , X.Item.value('@Monto', 'DECIMAL(14,2)') AS Monto
    FROM @inXmlData.nodes('/Datos/Movimientos/movimiento') AS X(Item);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoDocIdentidad (
            Id
            , Nombre
        )
        SELECT
            TD.Id
            , TD.Nombre
        FROM @tipoDocumento AS TD
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoDocIdentidad AS TDI
            WHERE (TDI.Id = TD.Id)
        ));

        INSERT INTO dbo.Departamento (
            Id
            , Nombre
        )
        SELECT
            D.Id
            , D.Nombre
        FROM @departamento AS D
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Departamento AS DEP
            WHERE (DEP.Id = D.Id)
        ));

        INSERT INTO dbo.TipoEvento (
            Id
            , Nombre
        )
        SELECT
            TE.Id
            , TE.Nombre
        FROM @tipoEvento AS TE
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoEvento AS TEE
            WHERE (TEE.Id = TE.Id)
        ));

        INSERT INTO dbo.Feriado (
            Id
            , Nombre
            , Fecha
        )
        SELECT
            F.Id
            , F.Nombre
            , F.Fecha
        FROM @feriado AS F
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Feriado AS FE
            WHERE (FE.Id = F.Id)
        ));

        INSERT INTO dbo.TipoMovimiento (
            Id
            , Nombre
            , Accion
        )
        SELECT
            TM.Id
            , TM.Nombre
            , TM.Accion
        FROM @tipoMovimiento AS TM
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoMovimiento AS TMO
            WHERE (TMO.Id = TM.Id)
        ));

        INSERT INTO dbo.TipoDeduccion (
            Id
            , Nombre
            , EsObligatoria
            , EsPorcentual
            , Valor
            , IdTipoMovimiento
        )
        SELECT
            TD.Id
            , TD.Nombre
            , TD.EsObligatoria
            , TD.EsPorcentual
            , TD.Valor
            , TM.Id
        FROM @tipoDeduccion AS TD
        INNER JOIN dbo.TipoMovimiento AS TM
            ON TM.Nombre = TD.TipoMovimiento
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoDeduccion AS TDE
            WHERE (TDE.Id = TD.Id)
        ));

        INSERT INTO dbo.Puesto (
            Nombre
            , SalarioXHora
        )
        SELECT
            P.Nombre
            , P.SalarioXHora
        FROM @puesto AS P
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Puesto AS PU
            WHERE (PU.Nombre = P.Nombre)
        ));

        INSERT INTO dbo.TipoJornada (
            Id
            , Nombre
            , HoraInicio
            , HoraFin
        )
        SELECT
            TJ.Id
            , TJ.Nombre
            , TJ.HoraInicio
            , TJ.HoraFin
        FROM @tipoJornada AS TJ
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoJornada AS TJO
            WHERE (TJO.Id = TJ.Id)
        ));

        INSERT INTO dbo.Usuario (
            Username
            , PasswordHash
            , Tipo
        )
        SELECT
            U.Username
            , U.PasswordHash
            , U.Tipo
        FROM @usuario AS U
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Usuario AS US
            WHERE (US.Username = U.Username)
        ));

        INSERT INTO dbo.Usuario (
            Username
            , PasswordHash
            , Tipo
        )
        SELECT
            E.ValorDocumento
            , E.ValorDocumento
            , 'empleado'
        FROM @empleado AS E
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Usuario AS U
            WHERE (U.Username = E.ValorDocumento)
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
            , D.Id
            , TD.Id
            , U.Id
            , E.ValorDocumento
            , E.Nombre
            , E.ValorDocumento
            , E.FechaContratacion
            , 1
        FROM @empleado AS E
        INNER JOIN dbo.Puesto AS P
            ON P.Nombre = E.Puesto
        CROSS JOIN @departamento AS D
        CROSS JOIN @tipoDocumento AS TD
        INNER JOIN dbo.Usuario AS U
            ON U.Username = E.ValorDocumento
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Empleado AS EM
            WHERE (EM.ValorDocumento = E.ValorDocumento)
                OR (EM.Nombre = E.Nombre)
        ));

        INSERT INTO dbo.MovimientoAsistencia (
            IdMarcaAsistencia
            , IdTipoMovimiento
            , CantidadHoras
            , Monto
        )
        SELECT
            MA.Id
            , TM.Id
            , 0
            , MH.Monto
        FROM @movimientoHistorico AS MH
        INNER JOIN dbo.Empleado AS E
            ON E.ValorDocumento = MH.ValorDocumento
        INNER JOIN dbo.TipoMovimiento AS TM
            ON TM.Nombre = MH.TipoMovimiento
        INNER JOIN dbo.MarcaAsistencia AS MA
            ON MA.IdEmpleado = E.Id
            AND MA.Fecha = MH.Fecha
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.MovimientoAsistencia AS MV
            WHERE (MV.IdMarcaAsistencia = MA.Id)
                AND (MV.IdTipoMovimiento = TM.Id)
                AND (MV.CantidadHoras = 0)
                AND (MV.Monto = MH.Monto)
        ));

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
