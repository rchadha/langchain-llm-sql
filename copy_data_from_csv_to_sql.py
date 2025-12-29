import sqlite3, csv, re

DB_PATH = "my_transactions.db"
CSV_PATH = "accountactivity.csv" 

def money_to_float(s):
    if s is None:
        return None
    s = s.strip()
    if s == "" or s.lower() in {"na", "null"}:
        return None
    # remove $ , and spaces
    s = re.sub(r"[$,\s]", "", s)
    return float(s)

# map possible CSV headers to the table columns
ALIASES = {
    "date": "date",
    "transaction description": "transaction_description",
    "description": "transaction_description",
    "withdrawals": "withdrawals",
    "withdrawal": "withdrawals",
    "deposits": "deposits",
    "deposit": "deposits",
}

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

with open(CSV_PATH, newline="", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    rows = []
    for r in reader:
        # normalize keys
        norm = {ALIASES.get(k.strip().lower(), k.strip().lower()): v for k, v in r.items()}
        date = norm.get("transaction_date", norm.get("date"))
        desc = norm.get("transaction_description")
        wd = money_to_float(norm.get("withdrawals"))
        dp = money_to_float(norm.get("deposits"))
        rows.append((date, desc, wd, dp))

cur.executemany(
    "INSERT INTO accountactivity (date, transaction_description, withdrawals, deposits) VALUES (?, ?, ?, ?)",
    rows
)

conn.commit()
conn.close()
print(f"Inserted {len(rows)} rows.")
