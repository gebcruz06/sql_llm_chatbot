import os
import urllib.parse
from dotenv import load_dotenv
from langchain_community.utilities import SQLDatabase
from langchain_community.agent_toolkits import create_sql_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.agent_toolkits.sql.toolkit import SQLDatabaseToolkit
from langchain.agents.agent_types import AgentType

load_dotenv()

def create_connection_string():
    """Create SQL Server connection string from env variables"""
    server = os.getenv('SQL_SERVER', 'localhost\\SQLEXPRESS')
    database = os.getenv('SQL_DATABASE')
    username = os.getenv('SQL_USERNAME')
    password = os.getenv('SQL_PASSWORD')
    
    if not database:
        raise ValueError("SQL_DATABASE must be set in .env file")
    
    # Use ODBC Driver 17 for SQL Server specifically
    driver = 'ODBC Driver 17 for SQL Server'
    
    # Use Windows Authentication if username/password not provided
    if not username or not password:
        return f"mssql+pyodbc://{server}/{database}?driver={urllib.parse.quote_plus(driver)}&trusted_connection=yes&TrustServerCertificate=yes&Encrypt=no"
    
    return (f"mssql+pyodbc://{username}:{urllib.parse.quote_plus(password)}@"
            f"{server}/{database}?driver={urllib.parse.quote_plus(driver)}&"
            f"TrustServerCertificate=yes&Encrypt=no")

def get_sql_prompt():
    """SQL agent system prompt - Modified to ensure data is returned"""
    return """
    You are an expert SQL assistant for SQL Server 2022.
    
    CRITICAL RULES:
    - Generate ONLY SELECT statements
    - Use SQL Server syntax: TOP instead of LIMIT, GETDATE(), [] for identifiers
    - NEVER use INSERT, UPDATE, DELETE, DROP, CREATE, ALTER
    - ALWAYS execute your SQL query and return the ACTUAL DATA VALUES
    - When user asks for "top sellers", return the actual seller NAMES and values
    - When user asks for "customers", return the actual customer NAMES
    - Return the DATA, not just the query
    - Show actual results like: "John Smith - $5,000" not just "SELECT name, total..."
    
    Your response must include the actual data from executing the query.
    """

def setup_chatbot():
    """Initialize LLM, database, and agent"""
    # Initialize LLM
    llm = ChatGoogleGenerativeAI(
        model="gemma-3-4b-it",
        google_api_key=os.getenv('GOOGLE_API_KEY'),
        temperature=0
    )
    
    # Setup database connection
    connection_string = create_connection_string()
    db = SQLDatabase.from_uri(connection_string)
    
    # Create SQL agent with modified settings
    toolkit = SQLDatabaseToolkit(db=db, llm=llm)
    agent = create_sql_agent(
        llm=llm,
        toolkit=toolkit,
        agent_type=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
        verbose=True,
        handle_parsing_errors=True,
        prefix=get_sql_prompt(),
        return_intermediate_steps=True,  # This helps track what the agent is doing
        max_execution_time=60  # Prevent hanging
    )
    
    print(f"Connected to {os.getenv('SQL_DATABASE')} using ODBC Driver 17")
    print(f"Tables: {db.get_usable_table_names()}")
    
    return agent, db

def ask_question(agent, question):
    """Ask natural language question and ensure we get actual data results"""
    try:
        # Modify the question to be very explicit about wanting actual data
        enhanced_question = f"{question}. I need the actual data values/names from the database, not the SQL query. Execute the query and show me the results."
        
        response = agent.invoke({"input": enhanced_question})
        
        # Extract the output
        result = response.get("output", "")
        
        # Check if response contains actual data or just SQL
        # Look for table-like formatting or actual data patterns
        has_data_indicators = any([
            "|" in result,  # Table pipes
            "─" in result,  # Table lines  
            "│" in result,  # Box drawing
            "+" in result and "-" in result,  # ASCII table
            result.count("\n") > 3 and not result.strip().startswith("SELECT"),  # Multiple data rows
        ])
        
        # If it looks like just SQL without results, extract and execute
        if "SELECT" in result.upper() and not has_data_indicators:
            print("🔍 Agent returned SQL query, extracting and executing...")
            
            # Extract SQL more robustly
            import re
            sql_pattern = r'(SELECT.*?)(?:\n\n|\n$|$)'
            match = re.search(sql_pattern, result, re.IGNORECASE | re.DOTALL)
            
            if match:
                sql_query = match.group(1).strip()
                # Clean up common SQL formatting issues
                sql_query = sql_query.replace('```sql', '').replace('```', '').strip()
                
                print(f"📝 Executing: {sql_query}")
                try:
                    data_result = agent.toolkit.db.run(sql_query)
                    if data_result:
                        return f"📊 Results:\n{data_result}"
                    else:
                        return "📊 Query executed successfully but returned no data."
                except Exception as e:
                    return f"❌ Error executing query: {str(e)}\nQuery was: {sql_query}"
        
        return result
        
    except Exception as e:
        return f"❌ Error: {str(e)}"

def ask_question_direct(db, llm, question):
    """Alternative approach: Generate SQL and execute it directly"""
    try:
        # Create a prompt to generate SQL
        sql_prompt = f"""
        Given this question about the database: "{question}"
        
        Generate a SQL Server SELECT query to answer this question.
        Database tables available: {db.get_usable_table_names()}
        
        Return ONLY the SQL query, nothing else.
        """
        
        # Get SQL from LLM
        response = llm.invoke(sql_prompt)
        sql_query = response.content.strip()
        
        # Clean up the SQL (remove markdown formatting if present)
        if sql_query.startswith('```'):
            sql_query = sql_query.split('\n')[1:-1]
            sql_query = '\n'.join(sql_query)
        
        print(f"🔍 Generated SQL: {sql_query}")
        
        # Execute the SQL
        if sql_query.strip().upper().startswith('SELECT'):
            result = db.run(sql_query)
            return f"Query: {sql_query}\n\nResults:\n{result}"
        else:
            return "❌ Generated query is not a SELECT statement"
            
    except Exception as e:
        return f"❌ Error: {str(e)}"

def run_sql_query(db, sql):
    """Execute raw SQL (SELECT only)"""
    if not sql.strip().upper().startswith('SELECT'):
        return "❌ Only SELECT queries allowed"
    try:
        return db.run(sql)
    except Exception as e:
        return f"❌ SQL Error: {str(e)}"

def main():
    """Interactive chat mode"""
    print("🚀 Launching SQL Chatbot")
    
    agent, db = setup_chatbot()
    
    # Get LLM instance for direct method
    llm = ChatGoogleGenerativeAI(
        model="gemma-3-4b-it",
        google_api_key=os.getenv('GOOGLE_API_KEY'),
        temperature=0
    )

    print("\n📋 Commands:")
    print("  • Ask questions in natural language")
    print("  • 'sql: YOUR_QUERY' - Execute raw SELECT")
    print("  • 'direct: YOUR_QUESTION' - Use direct SQL generation method")
    print("  • Press Ctrl+C to quit")

    while True:
        try:
            question = input("\n❓ Question: ").strip()
            
            if question.lower().startswith('sql:'):
                result = run_sql_query(db, question[4:].strip())
                print(f"\n📝 Result:\n{result}")
            elif question.lower().startswith('direct:'):
                # Use the direct method
                answer = ask_question_direct(db, llm, question[7:].strip())
                print(f"\n💡 Answer:\n{answer}")
            elif question:
                # Use the agent method with enhancements
                answer = ask_question(agent, question)
                print(f"\n💡 Answer:\n{answer}")
                
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break

if __name__ == "__main__":
    main()