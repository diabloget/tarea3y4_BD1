USE PlanillaObrera;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_login
  @inUsername    VARCHAR(64)
, @inPassword    VARCHAR(128)
, @inIP          VARCHAR(45)
, @outResultCode INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @vIdUsuario INT;
  DECLARE @vIntentos  INT;
  DECLARE @vDescripcion VARCHAR(MAX);

  -- Verificar si el usuario existe
  SELECT @vIdUsuario = U.Id
  FROM   dbo.Usuario U
  WHERE  (U.Username = @inUsername);

  IF (@vIdUsuario IS NULL)
  BEGIN
    SET @outResultCode = 50001;

    -- Registrar intento fallido (Se cambia IdPostByUser por IdUsuario)
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, Descripcion, IdUsuario, PostInIP, PostTime)
    VALUES (2, 'Username no existe: ' + @inUsername, 1, @inIP, GETDATE());
    RETURN;
  END

  -- Verificar intentos fallidos
  SELECT @vIntentos = COUNT(*)
  FROM   dbo.BitacoraEvento BE
  WHERE  (BE.IdUsuario = @vIdUsuario)
  AND    (BE.IdTipoEvento = 2)
  AND    (BE.PostTime >= DATEADD(MINUTE, -20, GETDATE()));

  IF (@vIntentos >= 5)
  BEGIN
    SET @outResultCode = 50003;
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, Descripcion, IdUsuario, PostInIP, PostTime)
    VALUES (3, NULL, @vIdUsuario, @inIP, GETDATE());
    RETURN;
  END

  -- Verificar contraseña
  IF NOT EXISTS (SELECT 1 FROM dbo.Usuario U WHERE (U.Id = @vIdUsuario) AND (U.Password = @inPassword))
  BEGIN
    SET @outResultCode = 50002;
    SET @vIntentos = @vIntentos + 1;
    SET @vDescripcion = 'Intento ' + CAST(@vIntentos AS VARCHAR) + ' en los últimos 20 minutos. Código: 50002';
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, Descripcion, IdUsuario, PostInIP, PostTime)
    VALUES (2, @vDescripcion, @vIdUsuario, @inIP, GETDATE());
    RETURN;
  END

  SET @outResultCode = 0;

  -- Registrar intento exitoso
  INSERT INTO dbo.BitacoraEvento (IdTipoEvento, Descripcion, IdUsuario, PostInIP, PostTime)
  VALUES (1, 'Exitoso', @vIdUsuario, @inIP, GETDATE());

  SELECT U.Id
       , U.Username
  FROM   dbo.Usuario U
  WHERE  (U.Id = @vIdUsuario);
END;
GO
