USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_consultar_planillas_mensuales_empleado', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_consultar_planillas_mensuales_empleado;
END
GO

CREATE PROCEDURE dbo.sp_consultar_planillas_mensuales_empleado
    @inIdEmpleado INT
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY
        SELECT TOP (12)
            M.Id AS IdMes
            , M.FechaInicio
            , M.FechaFin
            , SUM(PS.SalarioBruto) AS SalarioBrutoMensual
            , SUM(PS.TotalDeducciones) AS TotalDeduccionesMensual
            , SUM(PS.SalarioNeto) AS SalarioNetoMensual
        FROM dbo.PlanillaSemanal AS PS
        INNER JOIN dbo.Semana AS S
            ON S.Id = PS.IdSemana
        INNER JOIN dbo.Mes AS M
            ON M.Id = S.IdMes
        WHERE (PS.IdEmpleado = @inIdEmpleado)
        GROUP BY
            M.Id
            , M.FechaInicio
            , M.FechaFin
        ORDER BY
            M.FechaInicio DESC;
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
