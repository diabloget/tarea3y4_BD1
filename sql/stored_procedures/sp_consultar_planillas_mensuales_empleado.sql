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
        PM.SalarioBruto AS SalarioBrutoMensual,
        PM.TotalDeducciones AS TotalDeduccionesMensual,
        PM.SalarioNeto AS SalarioNetoMensual
    FROM dbo.PlanillaMensual PM
    INNER JOIN dbo.Mes M ON M.Id = PM.IdMes
    WHERE PM.IdEmpleado = @IdEmpleado
    ORDER BY M.FechaInicio DESC;
END
GO
