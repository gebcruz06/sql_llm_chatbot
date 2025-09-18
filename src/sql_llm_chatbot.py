import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from db_handler import initialize_database, execute_query

load_dotenv()

# SQL Server rules that must be followed consistently
SQL_SERVER_RULES = """
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
"""


def generate_sql(llm, question: str, schema: str) -> str:
    """Generate SQL with retry logic"""
    prompt = f"""
    Convert this question to SQL Server query: "{question}"

    Database Schema:
    {schema}

    {SQL_SERVER_RULES}

    SQL:
    """
    
    response = llm.invoke(prompt)
    sql = response.content.strip()
    
    # Clean up formatting
    if sql.startswith("```"):
        sql = "\n".join(line for line in sql.splitlines() if not line.startswith("```")).strip()
    
    return sql


def ask_question(llm, db, question: str, schema: str):
    """Main query function"""
    sql = generate_sql(llm, question, schema)
    print(f"\n📝 SQL: {sql}")
    
    result = execute_query(db, sql, llm, question, schema, SQL_SERVER_RULES)
    
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

    # Initialize LLM
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemma-3-4b-it",
            google_api_key=os.getenv('GOOGLE_API_KEY'),
            temperature=0
        )
    except Exception as e:
        print(f"❌ LLM setup failed: {e}")
        return

    # Initialize database
    try:
        db, schema = initialize_database()
        print(f"✅ Connected to {os.getenv('SQL_DATABASE')}")
        print(f"📊 Tables: {', '.join(db.get_usable_table_names())}")
    except Exception as e:
        print(f"❌ Database setup failed: {e}")
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