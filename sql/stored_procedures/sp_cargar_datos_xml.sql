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

    DECLARE @error TABLE (
        Codigo INT NOT NULL PRIMARY KEY
        , Descripcion VARCHAR(255) NOT NULL
    );

    SET @outResultCode = 0;

    BEGIN TRY

        IF (
            @inXmlData.exist('/Datos') = 0
            OR @inXmlData.value('count(/Datos/Puestos/Puesto)', 'INT') <> 10
            OR @inXmlData.value('count(/Datos/TiposJornada/TipoJornada)', 'INT') <> 3
            OR @inXmlData.value('count(/Datos/Feriados/Feriado)', 'INT') <> 9
            OR @inXmlData.value('count(/Datos/TiposEvento/TipoEvento)', 'INT') <> 23
            OR @inXmlData.value('count(/Datos/TiposMovimiento/TipoMovimiento)', 'INT') <> 8
            OR @inXmlData.value('count(/Datos/TiposDeduccion/TipoDeduccion)', 'INT') <> 4
            OR @inXmlData.value('count(/Datos/Usuarios/Usuario)', 'INT') <> 3
            OR @inXmlData.value('count(/Datos/Error/error)', 'INT') <> 13
        )
        BEGIN
            INSERT INTO dbo.DBError (
                Mensaje
                , Severidad
                , Estado
            )
            VALUES (
                'Datos.xml no cumple el contrato oficial esperado'
                , 16
                , 1
            );

            SET @outResultCode = 50008;
            RETURN;
        END

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
        , CASE X.Item.value('@Accion', 'VARCHAR(50)')
            WHEN 'C' THEN '+'
            WHEN 'D' THEN '-'
            ELSE '+'
        END AS Accion
    FROM @inXmlData.nodes('/Datos/TiposMovimiento/TipoMovimiento') AS X(Item);

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
        , X.Item.value('@SalarioXHora', 'MONEY') AS SalarioXHora
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
        X.Item.value('@Username', 'VARCHAR(100)') AS Username
        , X.Item.value('@PasswordHash', 'VARCHAR(256)') AS PasswordHash
        , CASE X.Item.value('@Tipo', 'VARCHAR(50)')
            WHEN '1' THEN 'administrador'
            WHEN '2' THEN 'empleado'
            ELSE X.Item.value('@Tipo', 'VARCHAR(50)')
        END AS Tipo
    FROM @inXmlData.nodes('/Datos/Usuarios/Usuario') AS X(Item);

    INSERT INTO @error (
        Codigo
        , Descripcion
    )
    SELECT
        X.Item.value('@Codigo', 'INT') AS Codigo
        , X.Item.value('@Descripcion', 'VARCHAR(255)') AS Descripcion
    FROM @inXmlData.nodes('/Datos/Error/error') AS X(Item);

        IF (
            @inXmlData.exist('/Datos') = 0
            OR (SELECT COUNT(1) FROM @puesto AS P) <> 10
            OR (SELECT COUNT(1) FROM @tipoJornada AS TJ) <> 3
            OR (SELECT COUNT(1) FROM @feriado AS F) <> 9
            OR (SELECT COUNT(1) FROM @tipoEvento AS TE) <> 23
            OR (SELECT COUNT(1) FROM @tipoMovimiento AS TM) <> 8
            OR (SELECT COUNT(1) FROM @tipoDeduccion AS TD) <> 4
            OR (SELECT COUNT(1) FROM @usuario AS U) <> 3
            OR (SELECT COUNT(1) FROM @error AS E) <> 13
            OR EXISTS (
                SELECT
                    1
                FROM @tipoMovimiento AS TM
                WHERE (TM.Accion NOT IN ('+', '-'))
            )
            OR EXISTS (
                SELECT
                    1
                FROM @tipoDeduccion AS TD
                WHERE (NOT EXISTS (
                    SELECT
                        1
                    FROM @tipoMovimiento AS TM
                    WHERE (TM.Nombre = TD.TipoMovimiento)
                ))
            )
            OR EXISTS (
                SELECT
                    1
                FROM @usuario AS U
                WHERE (U.Tipo NOT IN ('administrador', 'empleado'))
            )
        )
        BEGIN
            INSERT INTO dbo.DBError (
                Mensaje
                , Severidad
                , Estado
            )
            VALUES (
                'Datos.xml no cumple el contrato oficial esperado'
                , 16
                , 1
            );

            SET @outResultCode = 50008;
            RETURN;
        END

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

        UPDATE TE
        SET
            TE.Nombre = TET.Nombre
        FROM dbo.TipoEvento AS TE
        INNER JOIN @tipoEvento AS TET
            ON TET.Id = TE.Id;

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

        UPDATE FE
        SET
            FE.Nombre = F.Nombre
            , FE.Fecha = F.Fecha
        FROM dbo.Feriado AS FE
        INNER JOIN @feriado AS F
            ON F.Id = FE.Id;

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

        UPDATE TMO
        SET
            TMO.Nombre = TM.Nombre
            , TMO.Accion = TM.Accion
        FROM dbo.TipoMovimiento AS TMO
        INNER JOIN @tipoMovimiento AS TM
            ON TM.Id = TMO.Id;

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

        UPDATE TDE
        SET
            TDE.Nombre = TD.Nombre
            , TDE.EsObligatoria = TD.EsObligatoria
            , TDE.EsPorcentual = TD.EsPorcentual
            , TDE.Valor = TD.Valor
            , TDE.IdTipoMovimiento = TM.Id
        FROM dbo.TipoDeduccion AS TDE
        INNER JOIN @tipoDeduccion AS TD
            ON TD.Id = TDE.Id
        INNER JOIN dbo.TipoMovimiento AS TM
            ON TM.Nombre = TD.TipoMovimiento;

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

        UPDATE PU
        SET
            PU.SalarioXHora = P.SalarioXHora
        FROM dbo.Puesto AS PU
        INNER JOIN @puesto AS P
            ON P.Nombre = PU.Nombre;

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

        UPDATE TJO
        SET
            TJO.Nombre = TJ.Nombre
            , TJO.HoraInicio = TJ.HoraInicio
            , TJO.HoraFin = TJ.HoraFin
        FROM dbo.TipoJornada AS TJO
        INNER JOIN @tipoJornada AS TJ
            ON TJ.Id = TJO.Id;

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

        UPDATE US
        SET
            US.PasswordHash = U.PasswordHash
            , US.Tipo = U.Tipo
        FROM dbo.Usuario AS US
        INNER JOIN @usuario AS U
            ON U.Username = US.Username;

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

        UPDATE ER
        SET
            ER.Descripcion = E.Descripcion
        FROM dbo.Error AS ER
        INNER JOIN @error AS E
            ON E.Codigo = ER.Codigo;

        INSERT INTO dbo.Error (
            Codigo
            , Descripcion
        )
        SELECT
            E.Codigo
            , E.Descripcion
        FROM @error AS E
        WHERE (NOT EXISTS (
            SELECT
                1
            FROM dbo.Error AS ER
            WHERE (ER.Codigo = E.Codigo)
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
