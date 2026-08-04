# SQL Server + Debezium + Kafka Setup

A complete Docker Compose stack for capturing SQL Server changes with Debezium and streaming them to Kafka.

## What This Does

- **SQL Server 2022** - Database with Change Data Capture (CDC) enabled on the `users` table
- **Debezium** - Monitors SQL Server for changes and streams them to Kafka
- **Kafka + Zookeeper** - Message broker for CDC events
- **Kafka UI** - Web dashboard to visualize topics and messages

Changes to the `dbo.users` table are automatically captured and available in the Kafka topic `mssql.dbo.users`.

## Quick Start

### Prerequisites
- Docker Desktop (or Docker + Docker Compose)
- ~10GB free disk space
- ~2 minutes for initial startup

### Start Everything

```bash
docker-compose up -d
```

This will:
1. Start Zookeeper, Kafka, SQL Server, Debezium, and Kafka UI
2. Initialize SQL Server with the `TestDB` database
3. Enable CDC on the `dbo.users` table
4. Create the `debezium` user with necessary permissions
5. Register the Debezium connector to capture changes

### Verify It's Working

```bash
# Check all services are running
docker-compose ps

# Verify SQL Server is ready
docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -C -Q "SELECT @@VERSION"

# Check Debezium connector is running
curl -s http://localhost:8083/connectors/sqlserver-cdc/status | jq '.tasks[0].state'
```

## Usage

### Web Dashboards

- **Kafka UI**: http://localhost:8080 - Browse topics, view messages, monitor Debezium connectors

### Insert Test Data

```bash
# Insert a single record
docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -C << 'EOF'
USE TestDB;
INSERT INTO dbo.users (name, email) VALUES ('John Doe', 'john@example.com');
EOF
```

Or use the automated test script:

```bash
# Insert 5 random records
bash test-insert.sh 5

# Insert 1 random record
bash test-insert.sh
```

### Read Changes from Kafka

```bash
# View recent messages from the users table
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic mssql.dbo.users \
  --from-beginning \
  --max-messages 10
```

Or use Kafka UI: http://localhost:8080 → Topics → `mssql.dbo.users`

## Troubleshooting: No Messages in Kafka

If you see the `mssql.dbo.users` topic in Kafka UI but it's empty, the debezium user needs additional permissions on CDC system tables:

```bash
bash fix-debezium-permissions.sh
```

This script will:
1. Grant comprehensive CDC permissions to the debezium user
2. Delete and re-register the connector
3. Restart the snapshot with the correct permissions

After running it, insert test data:
```bash
bash test-insert.sh 3
```

Messages should now appear in Kafka UI.

### Query SQL Server

```bash
# Connect to SQL Server
docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -C

# List all users
> USE TestDB;
> SELECT * FROM dbo.users;
> GO
```

## Architecture

```
SQL Server (1433)
    ↓ CDC captures changes
Debezium Connect (8083)
    ↓ sends events to
Kafka Broker (9092)
    ↓ viewed via
Kafka UI (8080)
    └─ Zookeeper (2181)
```

## Configuration

### Credentials

- **SQL Server SA**: `sa` / `YourPassword123!`
- **Debezium User**: `debezium` / `Deb3zium_P@ss`

⚠️ These are hardcoded for development. Change them in production:
- `docker-compose.yml` (SA_PASSWORD, MSSQL_AGENT_ENABLED)
- `init-sqlserver.sql` (debezium login password)
- `start-sqlserver.sh` (SA_PASSWORD reference)

### Database & Table

- **Database**: `TestDB`
- **Table**: `dbo.users` (columns: `id`, `name`, `email`, `created_at`)
- **CDC Topic**: `mssql.dbo.users`

To monitor additional tables, update `init-sqlserver.sql` to enable CDC on them and update `register-connector.sh` with their names.

## Troubleshooting

### Services won't start

```bash
# Check logs
docker-compose logs sqlserver
docker-compose logs debezium-connect
docker-compose logs kafka
```

### Connector shows as FAILED

```bash
# View detailed error
curl -s http://localhost:8083/connectors/sqlserver-cdc/status | jq '.tasks[0].trace'
```

Common issues:
- SQL Server not fully initialized yet (wait 30-60 seconds)
- Debezium user doesn't have CDC permissions (permissions are set automatically in `init-sqlserver.sql`)
- Kafka not reachable from Debezium

### No messages in Kafka

**Symptoms**: Kafka topic `mssql.dbo.users` exists but shows "No messages found"

**Root Cause**: The debezium user doesn't have sufficient permissions to read SQL Server's CDC system tables during snapshot.

**Solution**:
```bash
bash fix-debezium-permissions.sh
```

This grants the debezium user access to CDC capture tables and restarts the connector with a fresh snapshot.

**After fixing**:
1. Insert test data: `bash test-insert.sh 3`
2. Wait 2-5 seconds for CDC to capture
3. Check Kafka UI: http://localhost:8080 → Topics → `mssql.dbo.users`

**If still no messages**:
1. Verify connector is RUNNING: `curl -s http://localhost:8083/connectors/sqlserver-cdc/status | jq '.tasks[0].state'`
2. Check logs: `docker-compose logs debezium-connect | grep -i "error\|snapshot"`
3. Verify permissions: `docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U debezium -P 'Deb3zium_P@ss' -C -Q "SELECT * FROM TestDB.cdc.dbo_users_CT"`

### Port already in use

Modify `docker-compose.yml` to use different ports:
```yaml
sqlserver:
  ports:
    - "1434:1433"  # Change host port to 1434
```

## Cleanup

```bash
# Stop all services (keep data)
docker-compose down

# Stop and delete all data
docker-compose down -v

# Delete everything including images
docker-compose down -v --rmi all
```

## Files

- `docker-compose.yml` - Service definitions and networking
- `init-sqlserver.sql` - Database initialization script
- `start-sqlserver.sh` - SQL Server startup wrapper
- `register-connector.sh` - Debezium connector registration
- `test-insert.sh` - Generate and insert random test data
- `README.md` - This file

## Customization

### Add More Tables to Monitor

1. Edit `init-sqlserver.sql` - Add `EXEC sys.sp_cdc_enable_table` for each table
2. Update `register-connector.sh` - Add table names to `table.include.list`
3. Restart services: `docker-compose down -v && docker-compose up -d`

### Change SQL Server Version

Edit `docker-compose.yml`:
```yaml
sqlserver:
  image: mcr.microsoft.com/mssql/server:2019-latest  # or other version
```

### Use Different Kafka UI

Replace the `kafka-ui` service in `docker-compose.yml` with:
```yaml
kafdrop:
  image: obsidiandynamics/kafdrop:latest
  ports:
    - "9000:9000"
  environment:
    KAFKA_BROKERCONNECT: kafka:29092
```

## Next Steps

- Set up consumers in your application to read from Kafka topics
- Implement CDC-driven synchronization between SQL Server and other systems
- Add more tables and implement change event routing
- Set up monitoring and alerting for CDC lag

## References

- [Debezium SQL Server Connector](https://debezium.io/documentation/reference/stable/connectors/sqlserver.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka UI Documentation](https://github.com/provectus/kafka-ui)
