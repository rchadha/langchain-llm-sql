#### Setup Virtual Env

```
# Create venv
python3 -m venv langchain-llm-sql
# Activate
source langchain-llm-sql/bin/activate
```

### Deactivate venv
```
deactivate
```
### Delete a Virtual Environment
```
rm -rf langchain-llm-sql
```

### Install packages
```
pip install -r requirements.txt
```


### Download Chinook Database
https://database.guide/2-sample-databases-sqlite/

#### Download
curl -L -o Chinook_Sqlite.sqlite https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite

##### Create DB
sqlite3 Chinook.db

#### Load Chinook DB
.read Chinook_Sqlite.sql

#### Select
SELECT * FROM Artist LIMIT 10;

#### Exit
sqlite> .exit

#### Login to DB
sqlite3 Chinook_Sqlite.sqlite

### Run Flask App
python app.py

### CURL to test /query-sql endpoint
```
curl -X POST http://localhost:3002/query-sql \
  -H "Content-Type: application/json" \
  -d '{"query": "What are the names of the employees who live in USA?"}'
```