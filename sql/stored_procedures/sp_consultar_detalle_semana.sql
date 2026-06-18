USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_detalle_semana', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_consultar_detalle_semana;
END
GO

CREATE PROCEDURE dbo.sp_consultar_detalle_semana
    @inIdEmpleado INT
    , @inIdSemana INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    SELECT
        MA.Fecha
        , MA.HoraEntrada
        , MA.HoraSalida
        , TM.Nombre AS TipoMovimiento
        , MV.CantidadHoras
        , MV.Monto
    FROM dbo.MarcaAsistencia AS MA
    INNER JOIN dbo.HorarioJornada AS HJ
        ON HJ.Id = MA.IdHorarioJornada
    INNER JOIN dbo.Semana AS S
        ON S.Id = HJ.IdSemana
    INNER JOIN dbo.MovimientoAsistencia AS MV
        ON MV.IdMarcaAsistencia = MA.Id
    INNER JOIN dbo.TipoMovimiento AS TM
        ON TM.Id = MV.IdTipoMovimiento
    WHERE (MA.IdEmpleado = @inIdEmpleado)
        AND (HJ.IdSemana = @inIdSemana)
        AND (MA.Fecha BETWEEN S.FechaInicio AND S.FechaFin)
        AND (NOT EXISTS (
            SELECT
                1
            FROM dbo.TipoDeduccion AS TD
            WHERE (TD.IdTipoMovimiento = MV.IdTipoMovimiento)
        ))
    ORDER BY
        MA.Fecha ASC
        , MA.HoraEntrada ASC
        , TM.Nombre ASC;

    SELECT
        TD.Nombre AS NombreDeduccion
        , TD.EsPorcentual
        , CASE
            WHEN (TD.EsPorcentual = 1) THEN TD.Valor
            ELSE NULL
        END AS Porcentaje
        , SUM(MV.Monto) AS MontoDeducido
    FROM dbo.MarcaAsistencia AS MA
    INNER JOIN dbo.HorarioJornada AS HJ
        ON HJ.Id = MA.IdHorarioJornada
    INNER JOIN dbo.Semana AS S
        ON S.Id = HJ.IdSemana
    INNER JOIN dbo.MovimientoAsistencia AS MV
        ON MV.IdMarcaAsistencia = MA.Id
    INNER JOIN dbo.TipoDeduccion AS TD
        ON TD.IdTipoMovimiento = MV.IdTipoMovimiento
    WHERE (MA.IdEmpleado = @inIdEmpleado)
        AND (HJ.IdSemana = @inIdSemana)
        AND (MA.Fecha BETWEEN S.FechaInicio AND S.FechaFin)
    GROUP BY
        TD.Nombre
        , TD.EsPorcentual
        , TD.Valor
    ORDER BY
        TD.Nombre ASC;
END
GO
