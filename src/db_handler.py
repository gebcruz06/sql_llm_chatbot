import os
import urllib.parse
from langchain_community.utilities import SQLDatabase


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


def execute_query(db, sql: str, llm, question: str, schema: str, sql_rules: str, attempt: int = 1):
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
        
        # Generate corrected query with the same rules
        correction_prompt = f"""
        This SQL query failed: {sql}
        Error: {str(e)}
        
        Fix the query for this question: "{question}"
        
        Schema:
        {schema}
        
        {sql_rules}
        
        Return corrected SQL only:
        """
        
        corrected_sql = llm.invoke(correction_prompt).content.strip()
        if corrected_sql.startswith("```"):
            corrected_sql = "\n".join(line for line in corrected_sql.splitlines() if not line.startswith("```")).strip()
        
        print(f"🔄 Retry {attempt + 1}: {corrected_sql}")
        return execute_query(db, corrected_sql, llm, question, schema, sql_rules, attempt + 1)


def initialize_database():
    """Initialize database connection and return db object and schema"""
    try:
        db = SQLDatabase.from_uri(create_connection_string())
        schema = get_schema_info(db)
        return db, schema
    except Exception as e:
        raise Exception(f"Database initialization failed: {e}")