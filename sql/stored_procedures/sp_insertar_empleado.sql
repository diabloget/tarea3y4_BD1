USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_insertar_empleado', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_insertar_empleado;
GO

CREATE PROCEDURE dbo.sp_insertar_empleado
    @ValorDocumento    VARCHAR(50),
    @Nombre            VARCHAR(100),
    @NombrePuesto      VARCHAR(100),
    @CuentaBancaria    VARCHAR(100),
    @FechaContratacion DATE,
    @Username          VARCHAR(64) = NULL,
    @Password          VARCHAR(128) = NULL,
    @OutRespuesta      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdPuesto        INT;
    DECLARE @IdUsuario       INT;
    DECLARE @IdDepartamento  INT;
    DECLARE @IdTipoDocumento INT;

    -- Manejo del fallback para credenciales (si vienen vacíos o NULL, usan el documento)
    DECLARE @RealUsername VARCHAR(64) = ISNULL(NULLIF(@Username, ''), @ValorDocumento);
    DECLARE @RealPassword VARCHAR(128) = ISNULL(NULLIF(@Password, ''), @ValorDocumento);

    IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE ValorDocumento = @ValorDocumento)
    BEGIN
        SET @OutRespuesta = 50004; -- Documento repetido
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE Nombre = @Nombre)
    BEGIN
        SET @OutRespuesta = 50005; -- Nombre repetido
        RETURN;
    END

    SELECT @IdPuesto = Id FROM dbo.Puesto WHERE Nombre = @NombrePuesto;
    SELECT TOP 1 @IdDepartamento  = Id FROM dbo.Departamento;
    SELECT TOP 1 @IdTipoDocumento = Id FROM dbo.TipoDocIdentidad;

    IF @IdPuesto IS NULL OR @IdDepartamento IS NULL OR @IdTipoDocumento IS NULL
    BEGIN
        SET @OutRespuesta = 50008; -- Datos de referencia no encontrados
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Se insertan las credenciales extraídas
        INSERT INTO dbo.Usuario (Username, PasswordHash, Tipo)
        VALUES (@RealUsername, @RealPassword, 'empleado');

        SET @IdUsuario = SCOPE_IDENTITY();

        INSERT INTO dbo.Empleado (
            IdPuesto,
            IdDepartamento,
            IdTipoDocumento,
            IdUsuario,
            ValorDocumento,
            Nombre,
            CuentaBancaria,
            FechaContratacion,
            Activo
        )
        VALUES (
            @IdPuesto,
            @IdDepartamento,
            @IdTipoDocumento,
            @IdUsuario,
            @ValorDocumento,
            @Nombre,
            @CuentaBancaria,
            @FechaContratacion,
            1
        );

        COMMIT TRANSACTION;
        SET @OutRespuesta = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.DBError (Mensaje, Severidad, Estado)
        VALUES (ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE());

        SET @OutRespuesta = 50008;
    END CATCH
END
GO
