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
        SUM(Mov.Monto) AS MontoTotalMes
    FROM dbo.Mes M
    INNER JOIN dbo.MarcaAsistencia Marca
        ON Marca.Fecha BETWEEN M.FechaInicio AND M.FechaFin
    INNER JOIN dbo.MovimientoAsistencia Mov
        ON Mov.IdMarcaAsistencia = Marca.Id
    INNER JOIN dbo.TipoDeduccion TD
        ON TD.IdTipoMovimiento = Mov.IdTipoMovimiento
    WHERE Marca.IdEmpleado = @IdEmpleado
      AND M.Id = @IdMes
    GROUP BY TD.Nombre, TD.EsPorcentual, TD.Valor
    ORDER BY TD.Nombre ASC;
END
GO
