import os
import urllib.parse
from dotenv import load_dotenv
from langchain_community.utilities import SQLDatabase
from langchain_google_genai import ChatGoogleGenerativeAI

load_dotenv()

def create_connection_string():
    """Create SQL Server connection string from env variables"""
    server = os.getenv('SQL_SERVER', 'localhost\\SQLEXPRESS')
    database = os.getenv('SQL_DATABASE')
    username = os.getenv('SQL_USERNAME')
    password = os.getenv('SQL_PASSWORD')

    if not database:
        raise ValueError("SQL_DATABASE must be set in .env file")

    driver = 'ODBC Driver 17 for SQL Server'
    return (
        f"mssql+pyodbc://{username}:{urllib.parse.quote_plus(password)}@"
        f"{server}/{database}?driver={urllib.parse.quote_plus(driver)}&"
        f"TrustServerCertificate=yes&Encrypt=no"
    )

def get_schema_info(db: SQLDatabase) -> str:
    """Get comprehensive schema info with foreign keys"""
    schema = db.get_table_info()
    
    # Add foreign key relationships
    try:
        fk_query = """
        SELECT 
            tp.name AS Parent_Table,
            cp.name AS Parent_Column,
            tr.name AS Referenced_Table,
            cr.name AS Referenced_Column
        FROM sys.foreign_keys fk
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        INNER JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
        INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
        INNER JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
        INNER JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
        """
        fk_result = db.run(fk_query)
        if fk_result:
            schema += f"\n\nForeign Key Relationships:\n{fk_result}"
    except:
        pass  # Skip if foreign key query fails
    
    return schema

def generate_sql(llm, question: str, schema: str) -> str:
    """Generate SQL with retry logic"""
    prompt = f"""
    Convert this question to SQL Server query: "{question}"

    Database Schema:
    {schema}

    STRICT SQL SERVER RULES - YOU MUST FOLLOW THESE:
    1. Use ONLY tables/columns from the schema above - DO NOT invent columns
    2. MANDATORY SQL Server T-SQL syntax:
       - Use TOP N instead of LIMIT N
       - Use GETDATE() for current date/time
       - Use DATEPART(), YEAR(), MONTH(), DAY() for date functions
       - Use LEN() instead of LENGTH()
       - Use CHARINDEX() instead of LOCATE()
       - Use SUBSTRING() with SQL Server syntax
       - Use ISNULL() instead of COALESCE when possible
       - Use square brackets [table].[column] for identifiers with spaces/keywords
    3. Only SELECT queries allowed - NO INSERT/UPDATE/DELETE/DROP/CREATE/ALTER
    4. Always qualify column names as table.column or [table].[column]
    5. Use proper SQL Server JOIN syntax
    6. Use CASE WHEN for conditional logic
    7. Use GROUP BY with aggregate functions (COUNT, SUM, AVG, MIN, MAX)
    8. Use ORDER BY for sorting results

    SQL:
    """
    
    response = llm.invoke(prompt)
    sql = response.content.strip()
    
    # Clean up formatting
    if sql.startswith("```"):
        sql = "\n".join(line for line in sql.splitlines() if not line.startswith("```")).strip()
    
    return sql

def execute_query(db, sql: str, llm, question: str, schema: str, attempt: int = 1):
    """Execute query with retry on error"""
    if not sql.upper().startswith("SELECT"):
        return "Only SELECT queries allowed"
    
    try:
        result = db.run(sql)
        return result if result else "Query executed but returned no rows."
    except Exception as e:
        if attempt >= 3:
            return f"Query failed after 3 attempts. Error: {str(e)}"
        
        print(f"Attempt {attempt} failed: {str(e)}")
        
        # Generate corrected query
        correction_prompt = f"""
        This SQL query failed: {sql}
        Error: {str(e)}
        
        Fix the query for this question: "{question}"
        
        Schema:
        {schema}
        
        Return corrected SQL only:
        """
        
        corrected_sql = llm.invoke(correction_prompt).content.strip()
        if corrected_sql.startswith("```"):
            corrected_sql = "\n".join(line for line in corrected_sql.splitlines() if not line.startswith("```")).strip()
        
        print(f"🔄 Retry {attempt + 1}: {corrected_sql}")
        return execute_query(db, corrected_sql, llm, question, schema, attempt + 1)

def ask_question(llm, db, question: str, schema: str):
    """Main query function"""
    sql = generate_sql(llm, question, schema)
    print(f"\n📝 SQL: {sql}")
    
    result = execute_query(db, sql, llm, question, schema)
    
    if result.startswith("Query failed") or result.startswith("Only SELECT"):
        return result
    
    # Generate natural language response
    response_prompt = f"""
    Question: "{question}"
    SQL: {sql}
    Result: {result}
    
    Explain the result in natural language:
    """
    
    explanation = llm.invoke(response_prompt).content.strip()
    return explanation

def main():
    print("🚀 Launching SQL Chatbot")

    # Initialize
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemma-3-4b-it",
            google_api_key=os.getenv('GOOGLE_API_KEY'),
            temperature=0
        )
        db = SQLDatabase.from_uri(create_connection_string())
        schema = get_schema_info(db)
        
        print(f"✅ Connected to {os.getenv('SQL_DATABASE')}")
        print(f"📊 Tables: {', '.join(db.get_usable_table_names())}")
        
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        return

    print("\n📋 Instructions:")
    print("  • Ask questions to your database in natural language")
    print("  • Press Ctrl+C to quit")

    while True:
        try:
            question = input("\n❓ Question: ").strip()
            if not question:
                continue
            
            answer = ask_question(llm, db, question, schema)
            print(f"\n💡 Answer: {answer}")
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()