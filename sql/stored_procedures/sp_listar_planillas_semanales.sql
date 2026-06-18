USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_listar_planillas_semanales', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_listar_planillas_semanales;
END
GO

CREATE PROCEDURE dbo.sp_listar_planillas_semanales
    @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    SELECT
        PS.Id
        , E.Nombre AS EmpleadoNombre
        , E.ValorDocumento AS EmpleadoDocumento
        , S.Id AS SemanaId
        , CONVERT(VARCHAR(10), S.FechaInicio, 120) AS FechaInicio
        , CONVERT(VARCHAR(10), S.FechaFin, 120) AS FechaFin
        , PS.SalarioBruto
        , PS.HorasOrdinarias
        , PS.HorasExtraNormal
        , PS.HorasExtraDoble
    FROM dbo.PlanillaSemanal AS PS
    INNER JOIN dbo.Empleado AS E
        ON E.Id = PS.IdEmpleado
    INNER JOIN dbo.Semana AS S
        ON S.Id = PS.IdSemana
    ORDER BY
        S.FechaInicio DESC
        , E.Nombre ASC;
END
GO
