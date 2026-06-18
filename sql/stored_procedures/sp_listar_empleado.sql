USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_listar_empleado', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_listar_empleado;
END
GO

CREATE PROCEDURE dbo.sp_listar_empleado
    @inFiltroNombre VARCHAR(100) = NULL
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    SELECT
        E.Id
        , E.ValorDocumento
        , E.Nombre AS NombreEmpleado
        , P.Nombre AS Puesto
    FROM dbo.Empleado AS E
    INNER JOIN dbo.Puesto AS P
        ON P.Id = E.IdPuesto
    WHERE (
        @inFiltroNombre IS NULL
        OR LTRIM(RTRIM(@inFiltroNombre)) = ''
        OR E.Nombre LIKE '%' + @inFiltroNombre + '%'
    )
    ORDER BY
        E.Nombre ASC;
END
GO
