USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_desasociar_deduccion', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_desasociar_deduccion;
END
GO

CREATE PROCEDURE dbo.sp_desasociar_deduccion
    @inValorDocumento VARCHAR(50)
    , @inNombreDeduccion VARCHAR(100)
    , @inFechaFin DATE = NULL
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idEmpleado INT;
    DECLARE @idUsuario INT;
    DECLARE @idTipoDeduccion INT;
    DECLARE @idTipoEvento INT;
    DECLARE @fechaFin DATE;

    SET @outResultCode = 0;
    SET @fechaFin = ISNULL(@inFechaFin, CAST(GETDATE() AS DATE));

    SELECT
        @idEmpleado = E.Id
        , @idUsuario = E.IdUsuario
    FROM dbo.Empleado AS E
    WHERE (E.ValorDocumento = @inValorDocumento)
        AND (E.Activo = 1);

    SELECT
        @idTipoDeduccion = TD.Id
    FROM dbo.TipoDeduccion AS TD
    WHERE (TD.Nombre = @inNombreDeduccion);

    SELECT TOP (1)
        @idTipoEvento = TE.Id
    FROM dbo.TipoEvento AS TE
    WHERE (TE.Nombre = 'Update exitoso')
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

    IF (
        @idTipoDeduccion IS NULL
        OR @idTipoEvento IS NULL
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE DE
        SET
            DE.FechaFin = @fechaFin
        FROM dbo.DeduccionEmpleado AS DE
        WHERE (DE.IdEmpleado = @idEmpleado)
            AND (DE.IdTipoDeduccion = @idTipoDeduccion)
            AND (DE.FechaFin IS NULL);

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
            , 'Desasociacion de deduccion "'
                + @inNombreDeduccion
                + '" para empleado con documento: '
                + @inValorDocumento
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
