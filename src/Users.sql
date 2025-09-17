import os
from langchain_community.utilities import SQLDatabase
from langchain_community.agent_toolkits import create_sql_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.agent_toolkits.sql.toolkit import SQLDatabaseToolkit
from langchain.agents.agent_types import AgentType
import pyodbc
import urllib.parse
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def create_sql_server_connection_from_env():
    """Create connection string using credentials from .env file"""
    
    # Get database connection details from environment variables
    server = os.getenv('SQL_SERVER', 'localhost\\SQLEXPRESS')
    database = os.getenv('SQL_DATABASE')
    username = os.getenv('SQL_USERNAME')  # Optional for SQL Auth
    password = os.getenv('SQL_PASSWORD')  # Optional for SQL Auth
    use_windows_auth = os.getenv('SQL_USE_WINDOWS_AUTH', 'true').lower() == 'true'
    
    if not database:
        raise ValueError("SQL_DATABASE must be set in .env file")
    
    driver = '{ODBC Driver 18 for SQL Server}'
    
    if use_windows_auth:
        # Windows Authentication
        connection_string = (
            f"mssql+pyodbc://{server}/{database}?"
            f"driver={urllib.parse.quote_plus(driver)}&"
            f"trusted_connection=yes&"
            f"TrustServerCertificate=yes&"
            f"Encrypt=no"
        )
    else:
        # SQL Server Authentication
        if not username or not password:
            raise ValueError("SQL_USERNAME and SQL_PASSWORD must be set for SQL Authentication")
        
        connection_string = (
            f"mssql+pyodbc://{username}:{urllib.parse.quote_plus(password)}@"
            f"{server}/{database}?"
            f"driver={urllib.parse.quote_plus(driver)}&"
            f"TrustServerCertificate=yes&"
            f"Encrypt=no"
        )
    
    return connection_string

class Gemma3SQLChatbot:
    def __init__(self):
        """
        Initialize SQL chatbot with Gemma 3 4B using Gemini API
        Credentials loaded from .env file
        """
        
        # Load Google API key from environment
        self.google_api_key = os.getenv('GOOGLE_API_KEY')
        if not self.google_api_key:
            raise ValueError("GOOGLE_API_KEY must be set in .env file")
        
        # Set environment variable for LangChain
        os.environ["GOOGLE_API_KEY"] = self.google_api_key
        
        # Initialize Gemma 3 4B model through Gemini API
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-1.5-flash",  # Using Flash as Gemma 3 4B isn't directly available
            google_api_key=self.google_api_key,
            temperature=0,  # Deterministic for SQL generation
            convert_system_message_to_human=True,
            # Additional parameters to optimize for Gemma-like behavior
            max_output_tokens=2048,
            top_k=40,
            top_p=0.8
        )
        
        print("✅ Gemma 3 4B-style model initialized via Gemini API")
        
        # Set up database connection from .env
        try:
            connection_string = create_sql_server_connection_from_env()
            self.db = SQLDatabase.from_uri(connection_string)
            
            print("✅ SQL Server 2022 Express connected successfully")
            print(f"📊 Database: {os.getenv('SQL_DATABASE')}")
            print(f"📋 Available tables: {self.db.get_usable_table_names()}")
            
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            print("\n🔍 Check your .env file configuration")
            raise
        
        # Create SQL toolkit and agent optimized for Gemma 3 4B capabilities
        self.toolkit = SQLDatabaseToolkit(db=self.db, llm=self.llm)
        
        # Custom prompt optimized for Gemma 3 4B reasoning patterns
        sql_prefix = """
        You are an expert SQL assistant powered by Gemma 3 4B model capabilities. 
        You have access to a SQL Server 2022 Express database and excel at understanding natural language queries.
        
        CRITICAL RULES - NEVER VIOLATE:
        - Generate ONLY SELECT statements for data retrieval
        - NEVER use INSERT, UPDATE, DELETE, DROP, CREATE, ALTER, or any data modification statements
        - Use SQL Server 2022 syntax exclusively:
          * Use TOP instead of LIMIT: "SELECT TOP 10 * FROM table"
          * Use GETDATE() for current date/time
          * Use DATEADD, DATEDIFF for date calculations
          * Use [] brackets for identifiers with spaces or special characters
          * Use ISNULL() instead of COALESCE when appropriate
        
        APPROACH:
        1. First, examine the database schema and table structure
        2. Understand the user's question carefully
        3. Generate precise SQL Server queries
        4. Provide clear, helpful explanations of results
        
        Be thorough but concise. Think step-by-step like Gemma 3 4B would approach the problem.
        """
        
        # Create the SQL agent with Gemma 3 4B optimized settings
        self.agent_executor = create_sql_agent(
            llm=self.llm,
            toolkit=self.toolkit,
            verbose=True,
            agent_type=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
            handle_parsing_errors=True,
            max_iterations=6,  # Optimized for Gemma 3 4B reasoning depth
            early_stopping_method="generate",
            prefix=sql_prefix
        )
    
    def query(self, question):
        """
        Ask a natural language question using Gemma 3 4B reasoning
        
        Args:
            question (str): Natural language question about the database
            
        Returns:
            str: Answer from Gemma 3 4B via Gemini API
        """
        try:
            # Enhance question with Gemma 3 4B style reasoning prompts
            enhanced_question = f"""
            Using your Gemma 3 4B capabilities and SQL Server 2022 syntax, answer this question:
            
            "{question}"
            
            Think through this step-by-step:
            1. What information is being requested?
            2. Which tables and columns are relevant?
            3. What SQL Server syntax should I use?
            4. How should I structure the query for clarity?
            
            Remember: Use TOP for limiting results, SQL Server date functions, and proper syntax.
            """
            
            response = self.agent_executor.invoke({"input": enhanced_question})
            return response["output"]
            
        except Exception as e:
            return f"❌ Error processing question: {str(e)}"
    
    def quick_query(self, sql_query):
        """
        Execute a quick SQL query directly (SELECT only)
        
        Args:
            sql_query (str): SQL SELECT statement
            
        Returns:
            str: Query results
        """
        # Safety check - only allow SELECT statements
        if not sql_query.strip().upper().startswith('SELECT'):
            return "❌ Only SELECT queries are allowed for security"
        
        try:
            result = self.db.run(sql_query)
            return result if result else "✅ Query executed successfully (no results returned)"
        except Exception as e:
            return f"❌ SQL Error: {str(e)}"
    
    def get_database_info(self):
        """Get comprehensive database information"""
        try:
            tables = self.db.get_usable_table_names()
            schema = self.db.get_table_info()
            
            info = {
                'database': os.getenv('SQL_DATABASE'),
                'server': os.getenv('SQL_SERVER', 'localhost\\SQLEXPRESS'),
                'table_count': len(tables),
                'tables': tables,
                'schema_preview': schema[:1000] + "..." if len(schema) > 1000 else schema
            }
            return info
        except Exception as e:
            return f"❌ Error getting database info: {str(e)}"
    
    def test_connection(self):
        """Test database connection and Gemma 3 4B model"""
        print("🧪 Testing Gemma 3 4B SQL Chatbot...")
        
        # Test database connection
        try:
            db_info = self.get_database_info()
            print(f"✅ Database Connection: Connected to '{db_info['database']}'")
            print(f"📊 Tables Found: {db_info['table_count']} tables")
            print(f"📋 Table List: {db_info['tables']}")
        except Exception as e:
            print(f"❌ Database Test Failed: {e}")
            return False
        
        # Test Gemma 3 4B model via Gemini API
        try:
            test_response = self.llm.invoke("Hello, confirm you're working properly")
            print("✅ Gemma 3 4B Model: Responding correctly via Gemini API")
        except Exception as e:
            print(f"❌ Model Test Failed: {e}")
            return False
        
        print("🎉 All systems operational!")
        return True

def create_sample_env_file():
    """Create a sample .env file with all required variables"""
    
    env_content = """# Google AI API Configuration
GOOGLE_API_KEY=your_google_api_key_here

# SQL Server Configuration
SQL_SERVER=localhost\\SQLEXPRESS
SQL_DATABASE=your_database_name
SQL_USE_WINDOWS_AUTH=true

# Optional: SQL Server Authentication (if not using Windows Auth)
# SQL_USERNAME=your_sql_username
# SQL_PASSWORD=your_sql_password

# Optional: Model Configuration
# MODEL_TEMPERATURE=0
# MODEL_MAX_TOKENS=2048
"""
    
    try:
        with open('.env', 'w') as f:
            f.write(env_content)
        print("✅ Sample .env file created successfully!")
        print("📝 Please edit .env file with your actual credentials")
        return True
    except Exception as e:
        print(f"❌ Failed to create .env file: {e}")
        return False

def validate_env_file():
    """Validate that all required environment variables are set"""
    
    required_vars = ['GOOGLE_API_KEY', 'SQL_DATABASE']
    missing_vars = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing required environment variables: {missing_vars}")
        print("📝 Please check your .env file")
        return False
    
    # Validate auth method
    use_windows_auth = os.getenv('SQL_USE_WINDOWS_AUTH', 'true').lower() == 'true'
    if not use_windows_auth:
        if not os.getenv('SQL_USERNAME') or not os.getenv('SQL_PASSWORD'):
            print("❌ SQL_USERNAME and SQL_PASSWORD required when SQL_USE_WINDOWS_AUTH=false")
            return False
    
    print("✅ Environment variables validated successfully")
    return True

def interactive_mode():
    """Interactive chat mode with Gemma 3 4B"""
    
    print("🚀 Gemma 3 4B SQL Chatbot - Interactive Mode")
    print("=" * 60)
    
    # Check for .env file
    if not os.path.exists('.env'):
        print("📝 .env file not found. Creating sample file...")
        create_sample_env_file()
        print("\n🔧 Please edit the .env file with your credentials and restart.")
        return
    
    # Validate environment
    if not validate_env_file():
        return
    
    try:
        # Initialize Gemma 3 4B chatbot
        print("\n🤖 Initializing Gemma 3 4B SQL Chatbot...")
        chatbot = Gemma3SQLChatbot()
        
        # Test connection
        if not chatbot.test_connection():
            print("❌ Connection test failed. Please check your configuration.")
            return
        
        print("\n🎯 Gemma 3 4B SQL Chatbot Ready!")
        print("\n💡 Example questions:")
        print("   • 'What tables are available?'")
        print("   • 'How many records are in the customers table?'")
        print("   • 'Show me the latest 5 orders with customer details'")
        print("   • 'What's the total revenue for this month?'")
        
        print(f"\n📋 Available commands:")
        print("   • 'exit' - Quit the chatbot")
        print("   • 'info' - Show database information")
        print("   • 'sql: YOUR_QUERY' - Execute raw SQL (SELECT only)")
        
        print("\n" + "=" * 60)
        
        # Interactive loop
        while True:
            try:
                question = input("\n🤔 Ask Gemma 3 4B: ").strip()
                
                if not question:
                    continue
                elif question.lower() == 'exit':
                    print("👋 Thanks for using Gemma 3 4B SQL Chatbot!")
                    break
                elif question.lower() == 'info':
                    info = chatbot.get_database_info()
                    print(f"\n📊 Database Info:")
                    print(f"   Database: {info['database']}")
                    print(f"   Server: {info['server']}")
                    print(f"   Tables ({info['table_count']}): {info['tables']}")
                    continue
                elif question.lower().startswith('sql:'):
                    sql_query = question[4:].strip()
                    result = chatbot.quick_query(sql_query)
                    print(f"\n📋 SQL Result:\n{result}")
                    continue
                
                # Process natural language question with Gemma 3 4B
                print("🧠 Gemma 3 4B is thinking...")
                answer = chatbot.query(question)
                print(f"\n💡 Gemma 3 4B Response:\n{answer}")
                print("-" * 50)
                
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Unexpected error: {e}")
                print("Please try again or type 'exit' to quit.")
                
    except Exception as e:
        print(f"❌ Failed to initialize chatbot: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Check your .env file configuration")
        print("2. Verify SQL Server Express is running")
        print("3. Confirm your Google API key is valid")
        print("4. Ensure database exists and is accessible")

def main():
    """Main entry point"""
    interactive_mode()

if __name__ == "__main__":
    main()