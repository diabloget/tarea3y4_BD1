USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_detalle_semana', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consultar_detalle_semana;
GO

CREATE PROCEDURE dbo.sp_consultar_detalle_semana
    @IdEmpleado INT,
    @IdSemana   INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        MA.Fecha,
        MA.HoraEntrada,
        MA.HoraSalida,
        TM.Nombre AS TipoMovimiento,
        Mov.CantidadHoras,
        Mov.Monto
    FROM dbo.MarcaAsistencia MA
    INNER JOIN dbo.HorarioJornada HJ ON HJ.Id = MA.IdHorarioJornada
    INNER JOIN dbo.Semana S ON S.Id = HJ.IdSemana
    INNER JOIN dbo.MovimientoAsistencia Mov ON Mov.IdMarcaAsistencia = MA.Id
    INNER JOIN dbo.TipoMovimiento TM ON TM.Id = Mov.IdTipoMovimiento
    WHERE MA.IdEmpleado = @IdEmpleado
      AND HJ.IdSemana = @IdSemana
      AND MA.Fecha BETWEEN S.FechaInicio AND S.FechaFin
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.TipoDeduccion TD
          WHERE TD.IdTipoMovimiento = Mov.IdTipoMovimiento
      )
    ORDER BY MA.Fecha ASC, MA.HoraEntrada ASC, TM.Nombre ASC;

    SELECT
        TD.Nombre AS NombreDeduccion,
        TD.EsPorcentual,
        CASE WHEN TD.EsPorcentual = 1 THEN TD.Valor ELSE NULL END AS Porcentaje,
        SUM(Mov.Monto) AS MontoDeducido
    FROM dbo.MarcaAsistencia MA
    INNER JOIN dbo.HorarioJornada HJ ON HJ.Id = MA.IdHorarioJornada
    INNER JOIN dbo.Semana S ON S.Id = HJ.IdSemana
    INNER JOIN dbo.MovimientoAsistencia Mov ON Mov.IdMarcaAsistencia = MA.Id
    INNER JOIN dbo.TipoDeduccion TD ON TD.IdTipoMovimiento = Mov.IdTipoMovimiento
    WHERE MA.IdEmpleado = @IdEmpleado
      AND HJ.IdSemana = @IdSemana
      AND MA.Fecha BETWEEN S.FechaInicio AND S.FechaFin
    GROUP BY TD.Nombre, TD.EsPorcentual, TD.Valor
    ORDER BY TD.Nombre ASC;
END
GO
