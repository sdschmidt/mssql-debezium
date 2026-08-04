#!/bin/bash
set -e

echo "========================================"
echo "Fixing Debezium CDC Permissions"
echo "========================================"
echo ""

# Grant SQL Server permissions for Debezium user
echo "1. Granting SQL Server permissions to debezium user..."
docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -C << 'EOF'
USE master;
GO

GRANT EXECUTE ON sys.sp_cdc_get_ddl_history TO debezium;
GRANT EXECUTE ON sys.sp_cdc_get_captured_columns TO debezium;
GRANT SELECT ON cdc.lsn_time_mapping TO debezium;
GO

USE TestDB;
GO

GRANT SELECT ON cdc.change_tables TO debezium;
GRANT SELECT ON cdc.captured_columns TO debezium;
GRANT SELECT ON cdc.lsn_time_mapping TO debezium;
GRANT SELECT ON cdc.ddl_history TO debezium;
GRANT EXECUTE ON sys.sp_cdc_get_ddl_history TO debezium;
GRANT SELECT ON cdc.dbo_users_CT TO debezium;
GO
EOF

echo "✓ Permissions granted"
echo ""

# Delete existing connector
echo "2. Deleting existing Debezium connector..."
curl -s -X DELETE http://localhost:8083/connectors/sqlserver-cdc 2>/dev/null || true
sleep 2
echo "✓ Connector deleted"
echo ""

# Register fresh connector
echo "3. Registering fresh Debezium connector..."
RESPONSE=$(curl -s -X POST http://localhost:8083/connectors \
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
      "snapshot.mode": "initial",
      "database.encrypt": "false"
    }
  }')

if echo "$RESPONSE" | grep -q "error_code"; then
  echo "✗ Failed to register connector:"
  echo "$RESPONSE" | jq '.message'
  exit 1
fi

echo "✓ Connector registered"
echo ""

# Wait for connector to initialize
echo "4. Waiting for connector to initialize..."
sleep 3

# Check status
STATE=$(curl -s http://localhost:8083/connectors/sqlserver-cdc/status | jq -r '.tasks[0].state // "UNKNOWN"')
echo "✓ Connector state: $STATE"
echo ""

if [ "$STATE" = "RUNNING" ]; then
  echo "========================================"
  echo "✓ Debezium is ready!"
  echo "========================================"
  echo ""
  echo "Next steps:"
  echo "  1. Insert test data:"
  echo "     bash test-insert.sh 3"
  echo ""
  echo "  2. Check Kafka UI:"
  echo "     http://localhost:8080"
  echo "     Topics → mssql.dbo.users"
  echo ""
else
  echo "⚠ Connector state is $STATE"
  echo "Check logs: docker-compose logs debezium-connect"
fi
