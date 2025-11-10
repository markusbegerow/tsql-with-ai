-- =============================================
-- Stored Procedure: sp_TSQL_Query_with_AI
-- Description: Executes dynamic T-SQL, sends results to AI API, and returns AI analysis
-- =============================================
-- CONTACT:
-- Author:    Markus Begerow
-- Contact:   https://www.linkedin.com/in/markusbegerow/
-- Github:    https://github.com/markusbegerow
-- =============================================
-- PREREQUISITES:
-- Run this first to enable Ole Automation Procedures:
-- EXEC sp_configure 'Ole Automation Procedures', 1;
-- RECONFIGURE;

CREATE OR ALTER PROCEDURE dbo.sp_TSQL_Query_with_AI
    @SqlQuery NVARCHAR(MAX),
    @UserQuestion NVARCHAR(MAX) = NULL,
    @ApiUrl NVARCHAR(500) = NULL,
    @Token NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'gpt-3.5-turbo'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JsonData NVARCHAR(MAX);
    DECLARE @RequestBody NVARCHAR(MAX);
    DECLARE @ResponseText NVARCHAR(MAX);
    DECLARE @Object INT;
    DECLARE @Result INT;
    DECLARE @Status NVARCHAR(32);
    DECLARE @StatusCode INT;
    DECLARE @TempTableName NVARCHAR(200) = '##AI_Query_' + REPLACE(CAST(NEWID() AS NVARCHAR(50)), '-', '');
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @OAErrorSource NVARCHAR(255);
    DECLARE @OAErrorDescription NVARCHAR(255);

    BEGIN TRY
        -- Validate required parameters
        IF @ApiUrl IS NULL OR @Token IS NULL
        BEGIN
            RAISERROR('ERROR: @ApiUrl and @Token parameters are required. Please provide your API endpoint and authentication token.', 16, 1);
            RETURN;
        END

        -- Print input parameters
        PRINT '========================================';
        PRINT '--- INPUT PARAMETERS ---';
        PRINT '========================================';
        PRINT 'SQL Query: ' + @SqlQuery;
        PRINT '';
        PRINT 'User Question: ' + ISNULL(@UserQuestion, '(No question provided - will use default)');
        PRINT '========================================';
        PRINT '';

        -- Step 1: Execute dynamic SQL and convert to JSON
        PRINT '--- Step 1: Executing Query ---';

        -- First, execute query into a global temp table
        SET @Sql = N'SELECT * INTO ' + @TempTableName + N' FROM (' + @SqlQuery + N') AS SourceQuery';
        EXEC sp_executesql @Sql;

        -- Then convert temp table to JSON
        SET @Sql = N'SELECT @JsonOut = (SELECT * FROM ' + @TempTableName + N' FOR JSON AUTO)';
        EXEC sp_executesql @Sql, N'@JsonOut NVARCHAR(MAX) OUTPUT', @JsonOut = @JsonData OUTPUT;

        -- Clean up temp table
        SET @Sql = N'DROP TABLE ' + @TempTableName;
        EXEC sp_executesql @Sql;

        IF @JsonData IS NULL
            SET @JsonData = '[]';

        PRINT '';
        PRINT '--- Step 2: Query Results (JSON) ---';
        PRINT 'Data Length: ' + CAST(LEN(@JsonData) AS NVARCHAR(20)) + ' characters';

        -- Warn if data is very large
        IF LEN(@JsonData) > 500000
        BEGIN
            PRINT 'WARNING: Data is very large (' + CAST(LEN(@JsonData)/1024 AS NVARCHAR(20)) + ' KB). Consider using TOP or WHERE to limit results.';
        END

        PRINT 'Data Preview: ' + LEFT(@JsonData, 500) + '...';
        PRINT '';

        -- Step 2: Build API request body (OpenAI format)
        DECLARE @SystemMessage NVARCHAR(MAX) = N'You are analyzing SQL Server data. Here is the data from the query: ' + @JsonData;
        DECLARE @UserMessage NVARCHAR(MAX) = ISNULL(@UserQuestion, 'Please analyze this data and provide insights.');

        SET @RequestBody = N'{
  "model": "' + @Model + N'",
  "messages": [
    {
      "role": "system",
      "content": "' + STRING_ESCAPE(@SystemMessage, 'json') + N'"
    },
    {
      "role": "user",
      "content": "' + STRING_ESCAPE(@UserMessage, 'json') + N'"
    }
  ]
}';

        PRINT '--- Step 3: Building API Request ---';
        PRINT 'API URL: ' + @ApiUrl;
        PRINT 'Model: ' + @Model;
        PRINT 'Request Body Length: ' + CAST(LEN(@RequestBody) AS NVARCHAR(20)) + ' characters';
        PRINT '';

        -- Step 3: Make HTTP POST request
        PRINT '--- Step 4: Calling AI API ---';
        PRINT 'Sending request...';

        -- Use WinHttp.WinHttpRequest.5.1 instead of MSXML2 for better reliability
        EXEC @Result = sp_OACreate 'WinHttp.WinHttpRequest.5.1', @Object OUT;
        IF @Result <> 0
        BEGIN
            EXEC sp_OAGetErrorInfo @Object, @OAErrorSource OUT, @OAErrorDescription OUT;
            PRINT 'Failed to create WinHttp object. Error: ' + ISNULL(@OAErrorDescription, 'Unknown');
            RAISERROR('Failed to create WinHttp object', 16, 1);
            RETURN;
        END

        PRINT 'WinHttp object created successfully';

        -- Set timeout (60 seconds for receive, since we may have large payloads)
        PRINT 'Setting timeouts...';
        EXEC @Result = sp_OAMethod @Object, 'SetTimeouts', NULL, 30000, 60000, 30000, 120000;

        -- Disable SSL certificate validation (for testing - remove in production if needed)
        DECLARE @Option INT = 13056;  -- SslErrorIgnoreFlags: ignore all SSL errors
        EXEC @Result = sp_OAMethod @Object, 'SetOption', NULL, 4, @Option;

        -- Open connection (synchronous)
        PRINT 'Opening connection...';
        EXEC @Result = sp_OAMethod @Object, 'open', NULL, 'POST', @ApiUrl, 0;  -- 0 = synchronous
        IF @Result <> 0
        BEGIN
            PRINT 'ERROR: Failed to open connection. Result code: ' + CAST(@Result AS NVARCHAR(10));
            EXEC sp_OAGetErrorInfo @Object, @OAErrorSource OUT, @OAErrorDescription OUT;
            PRINT 'Error details: ' + ISNULL(@OAErrorDescription, 'Unknown');
            RAISERROR('Failed to open connection', 16, 1);
        END

        -- Set headers
        PRINT 'Setting headers...';
        DECLARE @AuthHeader NVARCHAR(600) = 'Bearer ' + @Token;
        EXEC @Result = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/json; charset=utf-8';
        EXEC @Result = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Authorization', @AuthHeader;

        -- Send request (synchronous mode means this will wait for response)
        PRINT 'Sending request and waiting for response...';
        EXEC @Result = sp_OAMethod @Object, 'send', NULL, @RequestBody;
        IF @Result <> 0
        BEGIN
            PRINT 'ERROR: Failed to send request. Result code: ' + CAST(@Result AS NVARCHAR(10));
            EXEC sp_OAGetErrorInfo @Object, @OAErrorSource OUT, @OAErrorDescription OUT;
            PRINT 'Error details: ' + ISNULL(@OAErrorDescription, 'Unknown');
            RAISERROR('Failed to send HTTP request', 16, 1);
        END

        PRINT 'Request sent successfully, response received.';

        -- Get response status
        PRINT 'Reading status code...';
        EXEC @Result = sp_OAGetProperty @Object, 'status', @StatusCode OUT;
        IF @Result <> 0
        BEGIN
            PRINT 'WARNING: Failed to get status code. Result code: ' + CAST(@Result AS NVARCHAR(10));
            EXEC sp_OAGetErrorInfo @Object, @OAErrorSource OUT, @OAErrorDescription OUT;
            PRINT 'Error details: ' + ISNULL(@OAErrorDescription, 'Unknown');
            SET @StatusCode = -1;
        END
        ELSE
        BEGIN
            PRINT 'Status code retrieved: ' + CAST(@StatusCode AS NVARCHAR(10));
        END

        PRINT 'Reading status text...';
        EXEC @Result = sp_OAGetProperty @Object, 'statusText', @Status OUT;
        IF @Result <> 0
        BEGIN
            PRINT 'WARNING: Failed to get status text. Result code: ' + CAST(@Result AS NVARCHAR(10));
        END

        -- Get response text using ADODB.Stream
        PRINT 'Reading response using ADODB.Stream...';

        DECLARE @StreamObject INT;
        DECLARE @ResponseStream INT;

        -- Try to get responseStream first
        EXEC @Result = sp_OAGetProperty @Object, 'responseStream', @ResponseStream OUT;

        IF @Result = 0 AND @ResponseStream IS NOT NULL
        BEGIN
            PRINT 'Got responseStream, reading content...';

            -- Create ADODB.Stream to read the response
            EXEC @Result = sp_OACreate 'ADODB.Stream', @StreamObject OUT;

            IF @Result = 0
            BEGIN
                -- Copy from response stream
                EXEC sp_OASetProperty @StreamObject, 'Type', 2; -- adTypeText
                EXEC sp_OASetProperty @StreamObject, 'Charset', 'UTF-8';
                EXEC sp_OAMethod @StreamObject, 'Open';

                -- Load from response stream
                EXEC sp_OAMethod @StreamObject, 'LoadFromStream', NULL, @ResponseStream;
                EXEC sp_OASetProperty @StreamObject, 'Position', 0;
                EXEC sp_OAGetProperty @StreamObject, 'ReadText', @ResponseText OUT;

                EXEC sp_OAMethod @StreamObject, 'Close';
                EXEC sp_OADestroy @StreamObject;

                IF @ResponseText IS NOT NULL
                    PRINT 'Response text read successfully. Length: ' + CAST(LEN(@ResponseText) AS NVARCHAR(20)) + ' characters';
                ELSE
                    PRINT 'Response text is NULL after reading';
            END
            ELSE
            BEGIN
                PRINT 'Failed to create ADODB.Stream';
            END
        END
        ELSE
        BEGIN
            PRINT 'Could not get responseStream, trying alternative method...';

            -- Alternative: Try to read response in chunks using AllResponseHeaders as a test
            DECLARE @ResponseHeaders NVARCHAR(MAX);
            EXEC @Result = sp_OAGetProperty @Object, 'getAllResponseHeaders', @ResponseHeaders OUT;

            IF @Result = 0
            BEGIN
                PRINT 'Response headers retrieved, API responded successfully';
                PRINT 'Headers preview: ' + LEFT(@ResponseHeaders, 200);
            END

            -- Try simpler responseText with error handling
            PRINT 'Attempting simplified responseText read...';

            BEGIN TRY
                -- Use a temp variable with smaller size first to test
                DECLARE @TempResponse VARCHAR(8000);
                EXEC @Result = sp_OAMethod @Object, 'responseText', @TempResponse OUT;

                IF @Result = 0 AND @TempResponse IS NOT NULL
                BEGIN
                    SET @ResponseText = CAST(@TempResponse AS NVARCHAR(MAX));
                    PRINT 'Got response (may be truncated): ' + CAST(LEN(@ResponseText) AS NVARCHAR(20)) + ' characters';
                END
                ELSE
                BEGIN
                    PRINT 'Failed to read response text. Setting empty JSON as response.';
                    SET @ResponseText = '{"error": "Could not read response text from API"}';
                END
            END TRY
            BEGIN CATCH
                PRINT 'Error reading responseText: ' + ERROR_MESSAGE();
                SET @ResponseText = '{"error": "Exception reading response: ' + ERROR_MESSAGE() + '"}';
            END CATCH
        END

        PRINT '';
        PRINT '--- Step 5: API Response Received ---';
        PRINT 'HTTP Status Code: ' + ISNULL(CAST(@StatusCode AS NVARCHAR(10)), 'NULL');
        PRINT 'HTTP Status Text: ' + ISNULL(@Status, 'NULL');

        IF @ResponseText IS NOT NULL
        BEGIN
            PRINT 'Response Length: ' + CAST(LEN(@ResponseText) AS NVARCHAR(20)) + ' characters';
            PRINT 'Response Preview (first 500 chars):';
            PRINT LEFT(@ResponseText, 500);
            PRINT '';
        END
        ELSE
        BEGIN
            PRINT '';
            PRINT '*** WARNING: Response text is NULL ***';
            PRINT 'This may indicate an API issue or encoding problem.';
            PRINT '';
        END

        -- Clean up
        EXEC sp_OADestroy @Object;

        -- Step 6: Parse and display AI response
        PRINT '--- Step 6: Parsing AI Response ---';

        IF @StatusCode IS NOT NULL AND @StatusCode = 200
        BEGIN
            -- Try to extract AI message from OpenAI format response
            DECLARE @AiMessage NVARCHAR(MAX);

            -- Parse JSON response to extract the AI's message
            SELECT @AiMessage = JSON_VALUE(@ResponseText, '$.choices[0].message.content');

            IF @AiMessage IS NULL
            BEGIN
                -- Fallback: try other response formats
                SELECT @AiMessage = ISNULL(
                    JSON_VALUE(@ResponseText, '$.message'),
                    JSON_VALUE(@ResponseText, '$.response')
                );
            END

            PRINT 'AI Message Extracted: ' + CASE WHEN @AiMessage IS NOT NULL THEN 'YES' ELSE 'NO (check Full_API_Response)' END;
            PRINT '';
            PRINT '========================================';
            PRINT '=== FINAL RESULTS ===';
            PRINT '========================================';

            -- Display results
            SELECT
                'Success' AS Status,
                @StatusCode AS StatusCode,
                @AiMessage AS AI_Response,
                @ResponseText AS Full_API_Response,
                @JsonData AS Query_Data_Sent;
        END
        ELSE
        BEGIN
            IF @StatusCode IS NULL
            BEGIN
                PRINT 'CRITICAL: HTTP Status Code is NULL!';
                PRINT 'This indicates the HTTP request failed completely.';
                PRINT '';
                PRINT 'Possible causes:';
                PRINT '1. Network connectivity issue';
                PRINT '2. API server not responding';
                PRINT '3. Request payload too large (you sent ' + CAST(LEN(@RequestBody)/1024 AS NVARCHAR(20)) + ' KB)';
                PRINT '4. Timeout occurred (check if API needs more than 30 seconds)';
                PRINT '';
            END
            ELSE
            BEGIN
                PRINT 'HTTP Error occurred!';
                PRINT '';
            END

            PRINT '========================================';
            PRINT '=== ERROR RESULTS ===';
            PRINT '========================================';

            -- Error response
            SELECT
                'Error' AS Status,
                @StatusCode AS StatusCode,
                @Status AS StatusText,
                @ResponseText AS Error_Response,
                CAST(LEN(@RequestBody)/1024 AS NVARCHAR(20)) + ' KB' AS Request_Size_Sent;
        END

    END TRY
    BEGIN CATCH
        -- Error handling
        SELECT
            'Exception' AS Status,
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;

        -- Clean up HTTP object if it exists
        IF @Object IS NOT NULL
            EXEC sp_OADestroy @Object;

        -- Clean up temp table if it exists
        IF OBJECT_ID(@TempTableName, 'U') IS NOT NULL
        BEGIN
            SET @Sql = N'DROP TABLE ' + @TempTableName;
            EXEC sp_executesql @Sql;
        END
    END CATCH
END;
GO

-- =============================================
-- USAGE EXAMPLES
-- =============================================

/*

-- Example 1: OpenAI
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT TOP 10 * FROM sys.tables',
    @UserQuestion = 'What tables exist in this database?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-openai-api-key-here',
    @Model = 'gpt-4';

-- Example 2: Ollama (local)
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT DB_NAME() AS DatabaseName, COUNT(*) AS TableCount FROM sys.tables',
    @UserQuestion = 'What database is this and how many tables does it have?',
    @ApiUrl = 'http://localhost:11434/v1/chat/completions',
    @Token = 'ollama',
    @Model = 'llama3.2';

-- Example 3: Sales analysis
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = '
        SELECT ''North'' AS Region, 15000 AS Sales, 45 AS Count
        UNION ALL SELECT ''South'', 8500, 23
        UNION ALL SELECT ''East'', 12000, 34
        UNION ALL SELECT ''West'', 9800, 28',
    @UserQuestion = 'Which region has the highest sales and what insights can you provide?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-3.5-turbo';

-- Example 4: Custom OpenAI-compatible endpoint
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT GETDATE() AS CurrentDateTime, @@VERSION AS SQLVersion',
    @UserQuestion = 'What SQL Server version is this?',
    @ApiUrl = 'http://your-server:1234/v1/chat/completions',
    @Token = 'your-token-here',
    @Model = 'your-model-name';

-- =============================================
-- CONTACT:
-- Author:    Markus Begerow
-- Contact:   https://www.linkedin.com/in/markusbegerow/
-- Github:    https://github.com/markusbegerow
-- =============================================

*/
