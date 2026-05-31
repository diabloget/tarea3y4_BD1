USE mi_db;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_obtener_error
  @inCodigo      INT
, @outResultCode INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY
    SELECT E.Descripcion
    FROM   dbo.Error E
    WHERE  (E.Codigo = @inCodigo);

    SET @outResultCode = 0;
  END TRY
  BEGIN CATCH
    SET @outResultCode = ERROR_NUMBER() + 50000;
    INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
    VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), GETDATE());
    THROW;
  END CATCH
END;
GO