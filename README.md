# AI-Powered SQL Query Analysis for SQL Server

Execute T-SQL queries and get AI-powered insights directly from SQL Server using OpenAI, Ollama, or any OpenAI-compatible API.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2016%2B-red)](https://www.microsoft.com/sql-server)

## 🎯 What This Does

This project provides a SQL Server stored procedure that:
1. Executes any dynamic T-SQL query
2. Automatically converts results to JSON
3. Sends data to an AI API (OpenAI, Ollama, or any OpenAI-compatible endpoint)
4. Returns AI-generated insights and analysis

**Perfect for:**
- Quick data analysis and insights
- Understanding unfamiliar tables and schemas
- Automated report generation
- Natural language queries against your database

## 🚀 Quick Start

### Prerequisites

- SQL Server 2016 or later
- Sysadmin privileges (for setup only)
- Network access to the AI API endpoint
- Valid API token

### Installation

**1. Enable Ole Automation Procedures**

```sql
USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO
```

**2. Create the Stored Procedure**

Run the `sp_TSQL_Query_with_AI.sql` script in your database:

```sql
USE YourDatabaseName;
GO

-- Execute the sp_TSQL_Query_with_AI.sql script
```

**3. Test the Installation**

```sql
-- Example with OpenAI
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT DB_NAME() AS DatabaseName, COUNT(*) AS TableCount FROM sys.tables',
    @UserQuestion = 'What database is this and how many tables does it have?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-openai-api-key-here',
    @Model = 'gpt-3.5-turbo';

-- Example with Ollama (local)
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT DB_NAME() AS DatabaseName, COUNT(*) AS TableCount FROM sys.tables',
    @UserQuestion = 'What database is this and how many tables does it have?',
    @ApiUrl = 'http://localhost:11434/v1/chat/completions',
    @Token = 'ollama',
    @Model = 'llama3.2';
```

## 📖 Usage

### Basic Syntax

```sql
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'YOUR SQL QUERY HERE',
    @UserQuestion = 'Your question about the data',
    @ApiUrl = 'YOUR_API_ENDPOINT',
    @Token = 'YOUR_API_TOKEN',
    @Model = 'MODEL_NAME';
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `@SqlQuery` | NVARCHAR(MAX) | ✅ Yes | - | The T-SQL query to execute |
| `@UserQuestion` | NVARCHAR(MAX) | ❌ No | Auto-generated | Question for the AI about the data |
| `@ApiUrl` | NVARCHAR(500) | ✅ Yes | NULL | API endpoint URL (OpenAI, Ollama, etc.) |
| `@Token` | NVARCHAR(500) | ✅ Yes | NULL | Bearer token for authentication |
| `@Model` | NVARCHAR(100) | ❌ No | `gpt-3.5-turbo` | AI model name |

### Output

The procedure returns a result set with:

| Column | Description |
|--------|-------------|
| `Status` | Success, Error, or Exception |
| `StatusCode` | HTTP status code (200 = success) |
| `AI_Response` | **The AI's analysis** (main result) |
| `Full_API_Response` | Complete JSON response from API |
| `Query_Data_Sent` | The JSON data that was sent to the API |

## 💡 Examples

### Example 1: Understand a Table Schema (OpenAI)

```sql
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT TOP 5 * FROM Products',
    @UserQuestion = 'What columns are in this table and what do they represent?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-4';
```

### Example 2: Analyze Sales Data (Ollama - Local)

```sql
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = '
        SELECT
            Region,
            SUM(Sales) AS TotalSales,
            AVG(Sales) AS AvgSales,
            COUNT(*) AS OrderCount
        FROM SalesData
        GROUP BY Region',
    @UserQuestion = 'Which region is performing best and what insights can you provide?',
    @ApiUrl = 'http://localhost:11434/v1/chat/completions',
    @Token = 'ollama',
    @Model = 'llama3.2';
```

### Example 3: Database Summary (Custom Endpoint)

```sql
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = '
        SELECT
            type_desc AS ObjectType,
            COUNT(*) AS Count
        FROM sys.objects
        WHERE type_desc IN (''USER_TABLE'', ''VIEW'', ''SQL_STORED_PROCEDURE'')
        GROUP BY type_desc',
    @UserQuestion = 'What does this tell us about the database structure?',
    @ApiUrl = 'http://your-server:1234/v1/chat/completions',
    @Token = 'your-token-here',
    @Model = 'your-model-name';
```

### Example 4: Performance Analysis (GPT-4)

```sql
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = '
        SELECT TOP 10
            DB_NAME(database_id) AS DatabaseName,
            COUNT(*) AS QueryCount,
            AVG(total_elapsed_time/execution_count)/1000 AS AvgDurationMS
        FROM sys.dm_exec_query_stats
        GROUP BY database_id
        ORDER BY QueryCount DESC',
    @UserQuestion = 'What are the query patterns and any performance concerns?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-4-turbo';
```

### Example 5: Multiple AI Providers

```sql
-- Using OpenAI GPT-4
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT * FROM Inventory WHERE Stock < 10',
    @UserQuestion = 'What products need restocking urgently?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key',
    @Model = 'gpt-4';

-- Using Ollama Llama 3.2 (free, local)
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT * FROM Inventory WHERE Stock < 10',
    @UserQuestion = 'What products need restocking urgently?',
    @ApiUrl = 'http://localhost:11434/v1/chat/completions',
    @Token = 'ollama',
    @Model = 'llama3.2';

-- Using LM Studio (local OpenAI-compatible server)
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT * FROM Inventory WHERE Stock < 10',
    @UserQuestion = 'What products need restocking urgently?',
    @ApiUrl = 'http://localhost:1234/v1/chat/completions',
    @Token = 'lm-studio',
    @Model = 'local-model';
```

## 📂 Project Structure

```
tsql/
├── sp_TSQL_Query_with_AI.sql        # Main stored procedure
├── README.md                # This file
```

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────────────┐
│  1. Execute T-SQL Query                                 │
│     └─> Convert results to JSON                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  2. Build API Request                                   │
│     System Message: "Here is the data: [JSON]"          │
│     User Message: "Your question about the data"        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  3. HTTP POST to AI API (WinHttp)                       │
│     Headers: Authorization, Content-Type                │
│     Body: OpenAI-compatible JSON payload                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  4. Parse AI Response                                   │
│     Extract: choices[0].message.content                 │
│     Return: AI insights + full response                 │
└─────────────────────────────────────────────────────────┘
```

## 🎨 Best Practices

### 1. Limit Result Size

```sql
-- ✅ Good: Limited results
SELECT TOP 100 * FROM LargeTable

-- ❌ Avoid: Entire large table (may exceed API limits)
SELECT * FROM LargeTable
```

### 2. Use Aggregations for Large Datasets

```sql
-- ✅ Better: Send aggregated insights
SELECT Category, COUNT(*), AVG(Price)
FROM Products
GROUP BY Category

-- ❌ Less efficient: Raw data when aggregates would work
SELECT * FROM Products
```

### 3. Ask Specific Questions

```sql
-- ✅ Good: Specific question
@UserQuestion = 'Which product category has the highest profit margin?'

-- ❌ Less useful: Generic question
@UserQuestion = 'Analyze this data'
```

### 4. Handle Sensitive Data

```sql
-- ✅ DO: Exclude PII
SELECT CustomerID, OrderCount, TotalSpent
FROM Customers

-- ❌ DON'T: Send sensitive information
SELECT CustomerID, Email, CreditCardNumber, SSN
FROM Customers
```

## 🔧 Troubleshooting

### Error: "SQL Server blocked access to procedure 'sys.sp_OACreate'"

**Solution:**
```sql
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
```

### Error: HTTP 401 Unauthorized

**Solution:** Check your API token
```sql
-- Pass the correct token as a parameter
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = '...',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-valid-token-here',
    @Model = 'gpt-3.5-turbo';
```

### Error: HTTP 422 Unprocessable Entity

**Possible causes:**
- Model name is incorrect for the provider
- JSON payload is malformed
- API endpoint URL is wrong

**Solution:** Verify your API settings match your provider's requirements

### Response is NULL

**Possible causes:**
- Query returned no results
- API response format changed
- Network/connectivity issue

**Solution:**
1. Check the `Messages` tab in SSMS for detailed logs
2. Review the `Full_API_Response` column
3. Test your API endpoint with a simple query first

### Error: Arithmetic overflow / Response reading issues

**Solution:** Already handled in the latest version with multiple fallback methods:
- Method 1: responseStream with ADODB.Stream
- Method 2: Response headers diagnostic
- Method 3: Chunked reading with smaller buffer
- Method 4: Error messages if all methods fail

## 🔒 Security Considerations

### 1. Token Security

⚠️ **Don't hardcode tokens in production!**

**Options:**
- Use encrypted stored procedures
- Store tokens in a secure configuration table
- Use SQL Server linked servers with credentials
- Implement external configuration management

### 2. SQL Injection Protection

The procedure uses `sp_executesql` but be careful:
- ✅ Only allow trusted users to execute
- ✅ Validate input if building queries programmatically
- ✅ Use parameterized queries where possible

### 3. Data Privacy

⚠️ **Be mindful of what data you send to external APIs**

- Don't send PII (Personal Identifiable Information)
- Check your organization's data governance policies
- Consider data residency requirements
- Audit and log API calls if needed

### 4. Network Security

- API uses HTTPS (SSL/TLS encrypted)
- Consider firewall rules for outbound connections
- SSL certificate validation can be configured

## 📊 Performance Notes

| Aspect | Notes |
|--------|-------|
| **Query Timeout** | Complex queries may timeout. Optimize before sending. |
| **JSON Size Limit** | NVARCHAR(MAX) = 2GB, but API may have smaller limits |
| **HTTP Timeout** | Default: 120 seconds receive timeout |
| **Data Size Warning** | Warns when data > 500 KB |
| **Recommended Size** | Keep payloads under 1 MB for best performance |

## 🛠️ Advanced Usage

### Create a Wrapper Procedure

For frequently-used queries, create a wrapper:

```sql
CREATE PROCEDURE dbo.sp_AnalyzeMonthlySales
    @Year INT,
    @Month INT
AS
BEGIN
    DECLARE @Query NVARCHAR(MAX) = '
        SELECT
            DATEPART(DAY, OrderDate) AS Day,
            SUM(Amount) AS Revenue,
            COUNT(*) AS Orders
        FROM Sales
        WHERE DATEPART(YEAR, OrderDate) = ' + CAST(@Year AS NVARCHAR) + '
          AND DATEPART(MONTH, OrderDate) = ' + CAST(@Month AS NVARCHAR) + '
        GROUP BY DATEPART(DAY, OrderDate)
        ORDER BY Day';

    EXEC dbo.sp_TSQL_Query_with_AI
        @SqlQuery = @Query,
        @UserQuestion = 'What are the daily sales trends for this month?',
        @ApiUrl = 'https://api.openai.com/v1/chat/completions',
        @Token = 'sk-your-api-key-here',
        @Model = 'gpt-3.5-turbo';
END;
GO

-- Use it:
EXEC dbo.sp_AnalyzeMonthlySales @Year = 2025, @Month = 1;
```

### Integration with Stored Procedures

```sql
CREATE PROCEDURE dbo.sp_GetProductInsights
    @CategoryID INT
AS
BEGIN
    -- Regular business logic
    DECLARE @Category NVARCHAR(100);
    SELECT @Category = CategoryName FROM Categories WHERE CategoryID = @CategoryID;

    -- Get AI insights
    EXEC dbo.sp_TSQL_Query_with_AI
        @SqlQuery = '
            SELECT ProductName, Price, Stock, SalesLast30Days
            FROM Products
            WHERE CategoryID = ' + CAST(@CategoryID AS NVARCHAR),
        @UserQuestion = 'What products in the ' + @Category + ' category need attention?',
        @ApiUrl = 'https://api.openai.com/v1/chat/completions',
        @Token = 'sk-your-api-key-here',
        @Model = 'gpt-3.5-turbo';
END;
```

## 🧪 Testing

### Quick Connectivity Test

```sql
-- Test with OpenAI
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT ''Hello'' AS Message',
    @UserQuestion = 'What does this say?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-3.5-turbo';

-- Test with Ollama (requires Ollama running locally)
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT ''Hello'' AS Message',
    @UserQuestion = 'What does this say?',
    @ApiUrl = 'http://localhost:11434/v1/chat/completions',
    @Token = 'ollama',
    @Model = 'llama3.2';
```

### Comprehensive Tests

```sql
-- Small query test
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT TOP 5 * FROM sys.tables',
    @UserQuestion = 'What are these tables?',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-3.5-turbo';

-- Aggregated summary test
EXEC dbo.sp_TSQL_Query_with_AI
    @SqlQuery = 'SELECT type_desc, COUNT(*) AS Count FROM sys.objects GROUP BY type_desc',
    @UserQuestion = 'Summarize the database objects',
    @ApiUrl = 'https://api.openai.com/v1/chat/completions',
    @Token = 'sk-your-api-key-here',
    @Model = 'gpt-4';
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## 🙏 Acknowledgments

- Compatible with OpenAI, Ollama, and other OpenAI-compatible APIs
- Inspired by the need for natural language database interactions
- Community feedback and testing

## 🔗 Related Resources

- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Ollama Documentation](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/) - Run local LLMs with OpenAI-compatible API
- [SQL Server Ole Automation](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/ole-automation-procedures-server-configuration-option)

## 🤖 Supported AI Providers

| Provider | Endpoint Example | Notes |
|----------|------------------|-------|
| **OpenAI** | `https://api.openai.com/v1/chat/completions` | Requires API key (paid) |
| **Ollama** | `http://localhost:11434/v1/chat/completions` | Free, runs locally |
| **LM Studio** | `http://localhost:1234/v1/chat/completions` | Free, runs locally |
| **LocalAI** | `http://localhost:8080/v1/chat/completions` | Free, runs locally |
| **Azure OpenAI** | `https://YOUR-RESOURCE.openai.azure.com/openai/deployments/YOUR-DEPLOYMENT/chat/completions?api-version=2024-02-15-preview` | Requires Azure subscription |
| **Custom** | Any OpenAI-compatible endpoint | Configure as needed |

## 🙋‍♂️ Get Involved

If you encounter any issues or have questions:
- 🐛 [Report bugs](https://github.com/markusbegerow/tsql-with-ai/issues)
- 💡 [Request features](https://github.com/markusbegerow/tsql-with-ai/issues)
- ⭐ Star the repo if you find it useful!

## ☕ Support the Project

If you like this project, support further development with a repost or coffee:

<a href="https://www.linkedin.com/sharing/share-offsite/?url=https://github.com/markusbegerow/tsql-with-ai" target="_blank"> <img src="https://img.shields.io/badge/💼-Share%20on%20LinkedIn-blue" /> </a>

[![Buy Me a Coffee](https://img.shields.io/badge/☕-Buy%20me%20a%20coffee-yellow)](https://paypal.me/MarkusBegerow?country.x=DE&locale.x=de_DE)

## 📬 Contact

- 🧑‍💻 [Markus Begerow](https://linkedin.com/in/markusbegerow)
- 💾 [GitHub](https://github.com/markusbegerow)
- ✉️ [Twitter](https://x.com/markusbegerow)

---

**Made with ❤️ for data professionals who want AI-powered insights in SQL Server**
