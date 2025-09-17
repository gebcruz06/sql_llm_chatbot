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

def generate_sql(llm, db, question: str) -> str:
    """Ask LLM to generate SQL query from natural language"""
    sql_prompt = f"""
    You are an expert SQL Server assistant.
    Convert the following natural language request into a SQL Server SELECT query:

    Request: "{question}"

    Use only tables available: {db.get_usable_table_names()}
    Follow these rules:
    - Only generate SELECT queries (no INSERT, UPDATE, DELETE, DROP, CREATE, ALTER).
    - Use SQL Server syntax (TOP instead of LIMIT, GETDATE(), square brackets for identifiers).
    - Return ONLY the SQL query. No explanations, no markdown formatting.
    """
    response = llm.invoke(sql_prompt)
    sql_query = response.content.strip()

    # Clean up SQL (in case markdown/code fences are present)
    if sql_query.startswith("```"):
        sql_query = "\n".join(
            line for line in sql_query.splitlines() if not line.startswith("```")
        ).strip()

    return sql_query

def execute_sql(db, sql: str):
    """Execute SQL safely and return results"""
    if not sql.upper().startswith("SELECT"):
        return "Only SELECT queries are allowed"
    try:
        result = db.run(sql)
        return result if result else "Query executed but returned no rows."
    except Exception as e:
        return f"SQL Error: {str(e)}\nQuery was: {sql}"

def ask_question(llm, db, question: str):
    sql_query = generate_sql(llm, db, question)
    print(f"\n📝 Generated SQL:\n{sql_query}") # always show generated query
    results = execute_sql(db, sql_query)
    return results

def main():
    print("🚀 Launching SQL Chatbot")

    # Init LLM + DB
    llm = ChatGoogleGenerativeAI(
        model="gemma-3-4b-it",
        google_api_key=os.getenv('GOOGLE_API_KEY'),
        temperature=0
    )
    db = SQLDatabase.from_uri(create_connection_string())

    print(f"Connected to {os.getenv('SQL_DATABASE')}")
    print(f"Tables: {db.get_usable_table_names()}")

    print("\n📋 Instructions:")
    print("  • Ask questions in natural language")
    print("  • Press Ctrl+C to quit")

    while True:
        try:
            question = input("\n❓ Ask a question: ").strip()
            if not question:
                continue
            answer = ask_question(llm, db, question)
            print(f"\n💡 Answer:\n{answer}")
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break

if __name__ == "__main__":
    main()
