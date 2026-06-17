USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_desasociar_deduccion', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_desasociar_deduccion;
GO

CREATE PROCEDURE dbo.sp_desasociar_deduccion
    @ValorDocumento  VARCHAR(50),
    @NombreDeduccion VARCHAR(100),
    @OutRespuesta    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdEmpleado INT;
    DECLARE @IdUsuario INT;
    DECLARE @IdTipoDeduccion INT;
    DECLARE @IdTipoEvento INT;
    DECLARE @InicioTransaccionPropia BIT = 0;

    SET @OutRespuesta = 0;

    SELECT
        @IdEmpleado = E.Id,
        @IdUsuario = E.IdUsuario
    FROM dbo.Empleado E
    WHERE E.ValorDocumento = @ValorDocumento
      AND E.Activo = 1;

    IF @IdEmpleado IS NULL
    BEGIN
        SET @OutRespuesta = 50001;
        RETURN;
    END

    SELECT @IdTipoDeduccion = TD.Id
    FROM dbo.TipoDeduccion TD
    WHERE TD.Nombre = @NombreDeduccion;

    IF @IdTipoDeduccion IS NULL
    BEGIN
        SET @OutRespuesta = 50008;
        RETURN;
    END

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @InicioTransaccionPropia = 1;
        END
        ELSE
            SAVE TRANSACTION sp_desasociar_ded_sp;

        UPDATE dbo.DeduccionEmpleado
        SET FechaFin = GETDATE()
        WHERE IdEmpleado = @IdEmpleado
          AND IdTipoDeduccion = @IdTipoDeduccion
          AND FechaFin IS NULL;

        SELECT TOP 1 @IdTipoEvento = Id
        FROM dbo.TipoEvento
        WHERE Nombre = 'Update exitoso';

        IF @IdTipoEvento IS NULL
        BEGIN
            SELECT TOP 1 @IdTipoEvento = Id
            FROM dbo.TipoEvento
            ORDER BY Id;
        END

        IF @IdTipoEvento IS NULL
        BEGIN
            THROW 50008, 'No existe un tipo de evento para registrar la desasociacion de deduccion.', 1;
        END

        INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
        VALUES (
            @IdTipoEvento,
            @IdUsuario,
            '127.0.0.1',
            'Desasociacion de deduccion "' + @NombreDeduccion + '" para empleado con documento: ' + @ValorDocumento
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
                ROLLBACK TRANSACTION sp_desasociar_ded_sp;
        END

        INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
        VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());

        SET @OutRespuesta = 50008;
    END CATCH
END
GO
