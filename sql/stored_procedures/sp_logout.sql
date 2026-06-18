USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_logout', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_logout;
GO

CREATE PROCEDURE dbo.sp_logout
    @inIdUsuario   INT,
    @inIP          VARCHAR(45),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Id = @inIdUsuario)
    BEGIN
        SET @outResultCode = 50001;
        RETURN;
    END

    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
    VALUES (4, @inIdUsuario, @inIP, 'Logout exitoso');

    SET @outResultCode = 0;
END;
GO
