#!/bin/bash

# Start SQL Server in the background
/opt/mssql/bin/sqlservr &

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
for i in {1..60}; do
  /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -Q "SELECT 1" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "SQL Server is ready!"
    break
  fi
  echo "Attempt $i/60 - waiting..."
  sleep 1
done

# Run the initialization script
echo "Running initialization script..."
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -i /init-sqlserver.sql

echo "Initialization complete!"

# Keep the process running
wait
