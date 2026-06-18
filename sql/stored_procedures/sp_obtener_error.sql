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

    SELECT
        DE.Id
        , DE.Mensaje
        , DE.Severidad
        , DE.Estado
        , DE.FechaHora
    FROM dbo.DBError AS DE
    WHERE (DE.Id = @inCodigo);
END
GO
