LLM SQL Chatbot
A proof-of-concept app to ask a database your data questions in human language.
The LLM will understand your question, write a SQL query for it, retrieve data, and translate the results back in human language.
This proof-of-concept uses free open-source components:
Gemma 3-4B (LLM), MS SQL Server Express 2022 (database), LangChain (framework)

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/23fe3b15-77eb-496b-8681-7425f342a53f" />

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/cff57911-13bb-438b-89c0-1501406c3f8b" />

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/c2f5a95b-0305-4103-a219-4d6945bd09b7" />

# SQL Chatbot Application Flow

This flowchart shows the complete workflow of the SQL chatbot application, from initialization to user interaction and query processing.

```mermaid
flowchart TD
    A[Start: main] --> B[Load Environment Variables]
    B --> C[Initialize ChatGoogleGenerativeAI]
    C --> D[Create SQL Connection String]
    D --> E[Connect to SQLDatabase]
    E --> F[Get Schema Info]
    F --> G{Setup Successful?}
    
    G -->|No| H[Print Error & Exit]
    G -->|Yes| I[Print Connection Success]
    I --> J[Print Available Tables]
    J --> K[Print Instructions]
    
    K --> L[Start Main Loop]
    L --> M[Get User Question Input]
    M --> N{Question Empty?}
    N -->|Yes| M
    N -->|No| O[Call ask_question]
    
    O --> P[generate_sql]
    P --> Q[Create SQL Generation Prompt]
    Q --> R[Send to LLM]
    R --> S[Clean Response Format]
    S --> T[Return SQL Query]
    
    T --> U[execute_query]
    U --> V{Query starts with SELECT?}
    V -->|No| W[Return Error: Only SELECT allowed]
    V -->|Yes| X[Try Execute SQL]
    
    X --> Y{Query Successful?}
    Y -->|Yes| Z[Return Results]
    Y -->|No| AA{Attempt < 3?}
    AA -->|No| BB[Return: Query failed after 3 attempts]
    AA -->|Yes| CC[Generate Correction Prompt]
    CC --> DD[Send to LLM for Correction]
    DD --> EE[Get Corrected SQL]
    EE --> FF[Recursive Call: execute_query with attempt+1]
    FF --> Y
    
    Z --> GG[Generate Natural Language Response]
    GG --> HH[Create Response Prompt]
    HH --> II[Send to LLM]
    II --> JJ[Return Explanation]
    
    W --> KK[Print Answer]
    BB --> KK
    JJ --> KK
    
    KK --> LL{Continue?}
    LL -->|Ctrl+C| MM[Print Goodbye & Exit]
    LL -->|Yes| M
    LL -->|Exception| NN[Print Error]
    NN --> M
    
    classDef startEnd fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef process fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef decision fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef error fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef success fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef llm fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    
    class A,MM startEnd
    class B,C,D,E,F,J,K,L,M,O,S,T,U,X,KK process
    class G,N,V,Y,AA,LL decision
    class H,W,BB,NN error
    class I,Z success
    class P,Q,R,CC,DD,GG,HH,II,JJ llm
```

## Key Components

### 🚀 Initialization Phase
- **Environment Setup**: Loads API keys and database credentials
- **LLM Connection**: Initializes Google Gemini AI model
- **Database Connection**: Connects to SQL Server database
- **Schema Discovery**: Retrieves table structures and relationships

### 🔄 Main Loop
- **User Input**: Accepts natural language questions
- **SQL Generation**: Converts questions to SQL queries using LLM
- **Query Execution**: Runs queries with retry logic and error correction
- **Response Generation**: Creates natural language explanations

### 🛡️ Safety & Error Handling
- **Query Validation**: Only SELECT statements allowed
- **Retry Logic**: Up to 3 attempts with automatic correction
- **Error Recovery**: Graceful handling of connection and query failures

### 🎨 Color Legend
- **Blue**: LLM operations and AI interactions
- **Purple**: General processing steps
- **Orange**: Decision points and conditionals
- **Red**: Error handling and failures
- **Green**: Success states and confirmations