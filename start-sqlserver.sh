#!/bin/bash
set -e

# Start SQL Server in the background
/opt/mssql/bin/sqlservr &
PID=$!

# Wait for SQL Server to be ready (up to 60 seconds)
echo "Waiting for SQL Server to be ready..."
for i in {1..60}; do
  if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" &>/dev/null; then
    echo "SQL Server is ready!"
    break
  fi
  echo "Attempt $i/60..."
  sleep 1
done

# Run initialization script if it exists
if [ -f /var/opt/mssql/init-sqlserver.sql ]; then
  echo "Running initialization script..."
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -i /var/opt/mssql/init-sqlserver.sql
  echo "Initialization complete!"
fi

# Wait for SQL Server process to finish
wait $PID
