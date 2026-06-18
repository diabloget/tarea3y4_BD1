USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_planillas_semanales_empleado', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_consultar_planillas_semanales_empleado;
END
GO

CREATE PROCEDURE dbo.sp_consultar_planillas_semanales_empleado
    @inIdEmpleado INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY
        SELECT TOP (10)
            PS.Id AS IdPlanilla
            , S.Id AS IdSemana
            , S.FechaInicio
            , S.FechaFin
            , PS.SalarioBruto
            , PS.TotalDeducciones
            , PS.SalarioNeto
            , PS.HorasOrdinarias
            , PS.HorasExtraNormal
            , PS.HorasExtraDoble
        FROM dbo.PlanillaSemanal AS PS
        INNER JOIN dbo.Semana AS S
            ON S.Id = PS.IdSemana
        WHERE (PS.IdEmpleado = @inIdEmpleado)
        ORDER BY
            S.FechaInicio DESC;
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.DBError (
            Mensaje
            , Severidad
            , Estado
        )
        VALUES (
            ERROR_MESSAGE()
            , ERROR_SEVERITY()
            , ERROR_STATE()
        );

        SET @outResultCode = 50008;
    END CATCH
END
GO
