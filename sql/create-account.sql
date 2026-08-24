SET NOCOUNT ON;
GO

IF EXISTS (
    SELECT 1 FROM [dbo].[NGSCUSER]
     WHERE [strUserId] = N'$(ACCOUNT_USER)'
)
BEGIN
    RAISERROR ('That Soma account already exists.', 16, 1);
    RETURN;
END;

INSERT INTO [dbo].[NGSCUSER] ([strUserId], [strPasswd], [strEmail])
VALUES (N'$(ACCOUNT_USER)', N'$(ACCOUNT_PASSWORD)', N'$(ACCOUNT_EMAIL)');
GO

SELECT [strUserId], [strEmail]
  FROM [dbo].[NGSCUSER]
 WHERE [strUserId] = N'$(ACCOUNT_USER)';
GO
