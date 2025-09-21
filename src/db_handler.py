import os
import re
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


def sanitize_sql(sql: str) -> str:
    """Sanitize SQL input to prevent injection attacks"""
    if not sql or not isinstance(sql, str):
        raise ValueError("Invalid SQL input")
    
    sql = sql.strip()
    if not sql.upper().startswith("SELECT"):
        raise ValueError("Only SELECT statements allowed")
    
    # Block dangerous patterns
    forbidden = [
        r'\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|EXEC|EXECUTE|SP_|XP_)\b',
        r';\s*\w',  # Stacked queries (semicolon followed by another statement)
        r'\bUNION\b.*\bSELECT\b',
        r'\b(OPENROWSET|OPENDATASOURCE|BULK)\b'
    ]
    
    sql_upper = sql.upper()
    for pattern in forbidden:
        if re.search(pattern, sql_upper):
            raise ValueError(f"Forbidden SQL pattern: {pattern}")
    
    if len(sql) > 2000:
        raise ValueError("Query too long")
    
    return sql


def get_schema_info(db: SQLDatabase) -> str:
    """Get comprehensive schema info with foreign keys"""
    schema = db.get_table_info()
    
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
        pass
    
    return schema


def execute_query(db, sql: str, llm, question: str, schema: str, sql_rules: str, attempt: int = 1):
    """Execute query with sanitization and retry on error"""
    try:
        safe_sql = sanitize_sql(sql)
    except ValueError as e:
        return f"Security validation failed: {str(e)}"
    
    try:
        result = db.run(safe_sql)
        return result if result else "Query executed but returned no rows."
    except Exception as e:
        if attempt >= 3:
            return f"Query failed after 3 attempts. Error: {str(e)}"
        
        print(f"Attempt {attempt} failed: {str(e)}")
        
        correction_prompt = f"""
        This SQL query failed: {safe_sql}
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