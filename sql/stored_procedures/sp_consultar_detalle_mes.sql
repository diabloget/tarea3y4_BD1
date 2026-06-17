USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_detalle_mes', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consultar_detalle_mes;
GO

CREATE PROCEDURE dbo.sp_consultar_detalle_mes
    @IdEmpleado INT,
    @IdMes      INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TD.Nombre AS NombreDeduccion,
        TD.EsPorcentual,
        CASE WHEN TD.EsPorcentual = 1 THEN TD.Valor ELSE NULL END AS Porcentaje,
        DXM.MontoTotal AS MontoTotalMes
    FROM dbo.PlanillaMensual PM
    INNER JOIN dbo.DeduccionXMes DXM ON DXM.IdPlanillaMensual = PM.Id
    INNER JOIN dbo.TipoDeduccion TD ON TD.Id = DXM.IdTipoDeduccion
    WHERE PM.IdEmpleado = @IdEmpleado
      AND PM.IdMes = @IdMes
    ORDER BY TD.Nombre ASC;
END
GO
