#!/bin/bash

# Wait for Debezium Connect to be ready
echo "Waiting for Debezium Connect to be ready..."
until curl -s http://debezium-connect:8083/connectors > /dev/null 2>&1; do
  echo "Debezium Connect not ready yet, waiting..."
  sleep 2
done

echo "Debezium Connect is ready!"

# Check if connector already exists
if curl -s http://debezium-connect:8083/connectors | grep -q "sqlserver-cdc"; then
  echo "Connector 'sqlserver-cdc' already registered"
  exit 0
fi

# Register the SQL Server CDC connector
echo "Registering SQL Server CDC connector..."
curl -X POST http://debezium-connect:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "sqlserver-cdc",
    "config": {
      "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
      "database.hostname": "sqlserver",
      "database.port": 1433,
      "database.user": "debezium",
      "database.password": "Deb3zium_P@ss",
      "database.names": "TestDB",
      "topic.prefix": "mssql",
      "table.include.list": "dbo.users",
      "schema.history.internal.kafka.bootstrap.servers": "kafka:29092",
      "schema.history.internal.kafka.topic": "dbhistory.testdb",
      "snapshot.mode": "initial_only",
      "database.encrypt": "false"
    }
  }'

echo ""
echo "Connector registration complete!"
