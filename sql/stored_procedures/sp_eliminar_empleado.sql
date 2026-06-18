USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_eliminar_empleado', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_eliminar_empleado;
END
GO

CREATE PROCEDURE dbo.sp_eliminar_empleado
    @inValorDocumento VARCHAR(50)
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idEmpleado INT;
    DECLARE @idUsuario INT;
    DECLARE @idTipoEvento INT;

    SET @outResultCode = 0;

    SELECT
        @idEmpleado = E.Id
        , @idUsuario = E.IdUsuario
    FROM dbo.Empleado AS E
    WHERE (E.ValorDocumento = @inValorDocumento);

    SELECT TOP (1)
        @idTipoEvento = TE.Id
    FROM dbo.TipoEvento AS TE
    WHERE (TE.Nombre = 'Eliminar empleado')
    ORDER BY
        TE.Id ASC;

    IF (@idTipoEvento IS NULL)
    BEGIN
        SELECT TOP (1)
            @idTipoEvento = TE.Id
        FROM dbo.TipoEvento AS TE
        ORDER BY
            TE.Id ASC;
    END

    IF (@idEmpleado IS NULL)
    BEGIN
        SET @outResultCode = 50001;
        RETURN;
    END

    IF (@idTipoEvento IS NULL)
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE E
        SET
            E.Activo = 0
        FROM dbo.Empleado AS E
        WHERE (E.Id = @idEmpleado);

        UPDATE U
        SET
            U.Activo = 0
        FROM dbo.Usuario AS U
        WHERE (U.Id = @idUsuario);

        INSERT INTO dbo.BitacoraEvento (
            IdTipoEvento
            , IdUsuario
            , IP
            , Descripcion
        )
        VALUES (
            @idTipoEvento
            , @idUsuario
            , '127.0.0.1'
            , 'Baja logica de empleado con documento: ' + @inValorDocumento
        );

        COMMIT TRANSACTION;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

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
