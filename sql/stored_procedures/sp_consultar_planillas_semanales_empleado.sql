USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_planillas_semanales_empleado', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consultar_planillas_semanales_empleado;
GO

CREATE PROCEDURE dbo.sp_consultar_planillas_semanales_empleado
    @IdEmpleado INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (10)
        PS.Id AS IdPlanilla,
        S.Id AS IdSemana,
        S.FechaInicio,
        S.FechaFin,
        PS.SalarioBruto,
        PS.TotalDeducciones,
        PS.SalarioNeto,
        PS.HorasOrdinarias,
        PS.HorasExtraNormal,
        PS.HorasExtraDoble
    FROM dbo.PlanillaSemanal PS
    INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
    WHERE PS.IdEmpleado = @IdEmpleado
    ORDER BY S.FechaInicio DESC;
END
GO
