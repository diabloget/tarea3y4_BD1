USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_eliminar_empleado', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_eliminar_empleado;
GO

CREATE PROCEDURE dbo.sp_eliminar_empleado
    @ValorDocumento VARCHAR(50),
    @OutRespuesta   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdEmpleado           INT;
    DECLARE @IdUsuario            INT;
    DECLARE @IdTipoEventoEliminar INT;
    DECLARE @InicioTransaccionPropia BIT = 0;

    SELECT
        @IdEmpleado = E.Id,
        @IdUsuario  = E.IdUsuario
    FROM dbo.Empleado E
    WHERE E.ValorDocumento = @ValorDocumento;

    IF @IdEmpleado IS NULL
    BEGIN
        SET @OutRespuesta = 50001; -- Empleado no existe
        RETURN;
    END

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @InicioTransaccionPropia = 1;
        END
        ELSE
            SAVE TRANSACTION sp_eliminar_empleado_savepoint;

        UPDATE dbo.Empleado
        SET Activo = 0
        WHERE Id = @IdEmpleado;

        IF COL_LENGTH('dbo.Usuario', 'Activo') IS NOT NULL
        BEGIN
            UPDATE dbo.Usuario
            SET Activo = 0
            WHERE Id = @IdUsuario;
        END
        ELSE
        BEGIN
            THROW 50008, 'La columna Activo no existe en dbo.Usuario.', 1;
        END

        SELECT TOP 1 @IdTipoEventoEliminar = Id
        FROM dbo.TipoEvento
        WHERE Nombre = 'Eliminar empleado';

        IF @IdTipoEventoEliminar IS NULL
        BEGIN
            THROW 50008, 'No existe un IdTipoEvento para "Eliminar empleado".', 1;
        END

        INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
        VALUES (
            @IdTipoEventoEliminar,
            @IdUsuario,
            '127.0.0.1',
            'Baja lógica de empleado con documento: ' + @ValorDocumento
        );

        IF @InicioTransaccionPropia = 1
            COMMIT TRANSACTION;

        SET @OutRespuesta = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            IF @InicioTransaccionPropia = 1 OR XACT_STATE() = -1
                ROLLBACK TRANSACTION;
            ELSE
                ROLLBACK TRANSACTION sp_eliminar_empleado_savepoint;
        END

        INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
        VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());

        SET @OutRespuesta = 50008;
    END CATCH
END
GO
