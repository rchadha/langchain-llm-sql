# import pyodbc
from langchain_openai import ChatOpenAI
from langchain_community.utilities import SQLDatabase
from langchain_community.agent_toolkits import create_sql_agent
from langchain.agents.agent_types import AgentType
from langchain_community.utilities import SQLDatabase
from langchain_community.agent_toolkits.sql.toolkit import SQLDatabaseToolkit
from dotenv import load_dotenv
import os

# Load the API key from the .env file
load_dotenv()

# Set up the OpenAI API key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Connect to the SQL Server database
db_uri = "sqlite:///./Chinook_Sqlite.sqlite"
db = SQLDatabase.from_uri(db_uri)

llm = ChatOpenAI(temperature=0, model="gpt-4o", api_key=OPENAI_API_KEY)

sql_toolkit = SQLDatabaseToolkit(db=db, llm=llm)
sql_toolkit.get_tools()

# Create the agent
agent = create_sql_agent(
    llm=llm,
    toolkit=sql_toolkit,
    agent_type=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)

print(agent.run("What are the names of the employees who live in Canada?"))
