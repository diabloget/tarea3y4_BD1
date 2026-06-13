USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_listar_planillas_semanales', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_listar_planillas_semanales;
GO

CREATE PROCEDURE dbo.sp_listar_planillas_semanales
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        P.Id,
        E.Nombre AS EmpleadoNombre,
        E.ValorDocumento AS EmpleadoDocumento,
        S.Id AS SemanaId,
        CONVERT(VARCHAR(10), S.FechaInicio, 120) AS FechaInicio,
        CONVERT(VARCHAR(10), S.FechaFin, 120) AS FechaFin,
        P.SalarioBruto,
        P.HorasOrdinarias,
        P.HorasExtraNormal,
        P.HorasExtraDoble
    FROM dbo.PlanillaSemanal P
    INNER JOIN dbo.Empleado E ON P.IdEmpleado = E.Id
    INNER JOIN dbo.Semana S ON P.IdSemana = S.Id
    ORDER BY S.FechaInicio DESC, E.Nombre ASC;
END
GO
