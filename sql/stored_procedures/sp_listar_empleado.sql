USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_listar_empleado', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_listar_empleado;
GO

CREATE PROCEDURE dbo.sp_listar_empleado
    @FiltroNombre VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        E.Id,
        E.ValorDocumento,
        E.Nombre AS NombreEmpleado,
        P.Nombre AS Puesto
    FROM
        dbo.Empleado E
    INNER JOIN
        dbo.Puesto P ON E.IdPuesto = P.Id
    WHERE
        (@FiltroNombre IS NULL OR LTRIM(RTRIM(@FiltroNombre)) = ''
        OR E.Nombre LIKE '%' + @FiltroNombre + '%')
    ORDER BY
        E.Nombre ASC;
END
GO
