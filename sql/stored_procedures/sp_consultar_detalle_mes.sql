USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_detalle_mes', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_consultar_detalle_mes;
END
GO

CREATE PROCEDURE dbo.sp_consultar_detalle_mes
    @inIdEmpleado INT
    , @inIdMes INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    SELECT
        TD.Nombre AS NombreDeduccion
        , TD.EsPorcentual
        , CASE
            WHEN (TD.EsPorcentual = 1) THEN TD.Valor
            ELSE NULL
        END AS Porcentaje
        , SUM(MV.Monto) AS MontoTotalMes
    FROM dbo.Mes AS M
    INNER JOIN dbo.MarcaAsistencia AS MA
        ON MA.Fecha BETWEEN M.FechaInicio AND M.FechaFin
    INNER JOIN dbo.MovimientoAsistencia AS MV
        ON MV.IdMarcaAsistencia = MA.Id
    INNER JOIN dbo.TipoDeduccion AS TD
        ON TD.IdTipoMovimiento = MV.IdTipoMovimiento
    WHERE (MA.IdEmpleado = @inIdEmpleado)
        AND (M.Id = @inIdMes)
    GROUP BY
        TD.Nombre
        , TD.EsPorcentual
        , TD.Valor
    ORDER BY
        TD.Nombre ASC;
END
GO
