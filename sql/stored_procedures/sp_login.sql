USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_login', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_login;
END
GO

CREATE PROCEDURE dbo.sp_login
    @inUsername VARCHAR(64)
    , @inPassword VARCHAR(128)
    , @inIP VARCHAR(45)
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idUsuario INT;
    DECLARE @intentosFallidos INT;
    DECLARE @descripcion VARCHAR(MAX);

    SET @outResultCode = 0;

    SELECT
        @idUsuario = U.Id
    FROM dbo.Usuario AS U
    WHERE (U.Username = @inUsername)
        AND (U.Activo = 1);

    IF (@idUsuario IS NULL)
    BEGIN
        SET @outResultCode = 50001;
        RETURN;
    END

    SELECT
        @intentosFallidos = COUNT(1)
    FROM dbo.BitacoraEvento AS BE
    WHERE (BE.IdUsuario = @idUsuario)
        AND (BE.IdTipoEvento = 2)
        AND (BE.FechaHora >= DATEADD(MINUTE, -20, GETDATE()));

    BEGIN TRY
        BEGIN TRANSACTION;

        IF (@intentosFallidos >= 5)
        BEGIN
            INSERT INTO dbo.BitacoraEvento (
                IdTipoEvento
                , IdUsuario
                , IP
                , Descripcion
            )
            VALUES (
                3
                , @idUsuario
                , @inIP
                , 'Bloqueo por intentos fallidos'
            );

            SET @outResultCode = 50003;

            COMMIT TRANSACTION;
            RETURN;
        END

        IF (NOT EXISTS (
            SELECT
                1
            FROM dbo.Usuario AS U
            WHERE (U.Id = @idUsuario)
                AND (U.PasswordHash = @inPassword)
        ))
        BEGIN
            SET @intentosFallidos = @intentosFallidos + 1;
            SET @descripcion = 'Intento fallido #'
                + CAST(@intentosFallidos AS VARCHAR(10));

            INSERT INTO dbo.BitacoraEvento (
                IdTipoEvento
                , IdUsuario
                , IP
                , Descripcion
            )
            VALUES (
                2
                , @idUsuario
                , @inIP
                , @descripcion
            );

            SET @outResultCode = 50002;

            COMMIT TRANSACTION;
            RETURN;
        END

        INSERT INTO dbo.BitacoraEvento (
            IdTipoEvento
            , IdUsuario
            , IP
            , Descripcion
        )
        VALUES (
            1
            , @idUsuario
            , @inIP
            , 'Login exitoso'
        );

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
        RETURN;
    END CATCH

    SELECT
        U.Id
        , U.Username
        , U.Tipo
        , E.Id AS IdEmpleado
    FROM dbo.Usuario AS U
    LEFT JOIN dbo.Empleado AS E
        ON E.IdUsuario = U.Id
    WHERE (U.Id = @idUsuario);
END
GO
