USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_planillas_mensuales_empleado', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consultar_planillas_mensuales_empleado;
GO

CREATE PROCEDURE dbo.sp_consultar_planillas_mensuales_empleado
    @IdEmpleado INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (12)
        M.Id AS IdMes,
        M.FechaInicio,
        M.FechaFin,
        SUM(PS.SalarioBruto) AS SalarioBrutoMensual,
        SUM(PS.TotalDeducciones) AS TotalDeduccionesMensual,
        SUM(PS.SalarioNeto) AS SalarioNetoMensual
    FROM dbo.PlanillaSemanal PS
    INNER JOIN dbo.Semana S ON S.Id = PS.IdSemana
    INNER JOIN dbo.Mes M ON M.Id = S.IdMes
    WHERE PS.IdEmpleado = @IdEmpleado
    GROUP BY M.Id, M.FechaInicio, M.FechaFin
    ORDER BY M.FechaInicio DESC;
END
GO
