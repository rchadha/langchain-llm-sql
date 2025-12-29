FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY langchain_llm_sql.py .

# Copy database file (if it exists)
COPY Chinook_Sqlite.sqlite* ./

# Create directory for SQLite database if needed
RUN mkdir -p /app/data

# Expose the port the app runs on
EXPOSE 3002

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run the application
CMD ["python", "app.py"]
