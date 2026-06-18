USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_obtener_error', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_obtener_error;
END
GO

CREATE PROCEDURE dbo.sp_obtener_error
    @inCodigo INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY
        SELECT
            ER.Codigo
            , ER.Descripcion
        FROM dbo.Error AS ER
        WHERE (ER.Codigo = @inCodigo);
    END TRY
    BEGIN CATCH
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
