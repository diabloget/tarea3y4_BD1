USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_logout', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_logout;
END
GO

CREATE PROCEDURE dbo.sp_logout
    @inIdUsuario INT
    , @inIP VARCHAR(45)
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    IF (NOT EXISTS (
        SELECT
            1
        FROM dbo.Usuario AS U
        WHERE (U.Id = @inIdUsuario)
    ))
    BEGIN
        SET @outResultCode = 50001;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BitacoraEvento (
            IdTipoEvento
            , IdUsuario
            , IP
            , Descripcion
        )
        VALUES (
            4
            , @inIdUsuario
            , @inIP
            , 'Logout exitoso'
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
    END CATCH
END
GO
