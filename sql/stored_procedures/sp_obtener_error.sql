USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_obtener_error', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_obtener_error;
GO

CREATE PROCEDURE dbo.sp_obtener_error
    @inCodigo INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Mensaje,
        Severidad,
        Estado,
        FechaHora
    FROM dbo.DBError
    WHERE Id = @inCodigo;
END;
GO
