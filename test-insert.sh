#!/bin/bash

# Insert random test data into dbo.users
# Usage: ./test-insert.sh [count]
# Default: inserts 1 record

COUNT=${1:-1}

# Arrays of random first and last names
FIRST_NAMES=(
  "John" "Jane" "Michael" "Sarah" "David" "Emily" "Robert" "Jessica"
  "James" "Mary" "William" "Patricia" "Richard" "Jennifer" "Joseph" "Linda"
  "Charles" "Barbara" "Christopher" "Susan" "Daniel" "Jessica" "Matthew" "Karen"
  "Mark" "Nancy" "Donald" "Lisa" "George" "Betty" "Kenneth" "Margaret"
  "Steven" "Sandra" "Paul" "Ashley" "Andrew" "Kimberly" "Joshua" "Donna"
)

LAST_NAMES=(
  "Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis"
  "Rodriguez" "Martinez" "Hernandez" "Lopez" "Gonzalez" "Wilson" "Anderson" "Thomas"
  "Taylor" "Moore" "Jackson" "Martin" "Lee" "Perez" "Thompson" "White"
  "Harris" "Sanchez" "Clark" "Ramirez" "Lewis" "Robinson" "Young" "Walker"
  "Alvarado" "Mitchell" "Carter" "Roberts" "Gomez" "Phillips" "Evans" "Diaz"
)

DOMAINS=(
  "gmail.com" "yahoo.com" "outlook.com" "company.com" "example.com"
  "mail.com" "protonmail.com" "email.com" "test.com" "demo.com"
)

# SQL command to execute
SQL_COMMANDS=""

echo "Generating $COUNT random user records..."

for ((i=1; i<=COUNT; i++)); do
  # Generate random indices
  FIRST_INDEX=$((RANDOM % ${#FIRST_NAMES[@]}))
  LAST_INDEX=$((RANDOM % ${#LAST_NAMES[@]}))
  DOMAIN_INDEX=$((RANDOM % ${#DOMAINS[@]}))

  FIRST_NAME="${FIRST_NAMES[$FIRST_INDEX]}"
  LAST_NAME="${LAST_NAMES[$LAST_INDEX]}"
  DOMAIN="${DOMAINS[$DOMAIN_INDEX]}"

  # Construct name and email
  FULL_NAME="$FIRST_NAME $LAST_NAME"
  FIRST_LOWER=$(echo "$FIRST_NAME" | tr '[:upper:]' '[:lower:]')
  LAST_LOWER=$(echo "$LAST_NAME" | tr '[:upper:]' '[:lower:]')
  EMAIL="$FIRST_LOWER.$LAST_LOWER@$DOMAIN"

  # Build SQL command
  SQL_COMMANDS+="INSERT INTO dbo.users (name, email) VALUES ('$FULL_NAME', '$EMAIL');"$'\n'

  echo "  [$i/$COUNT] $FULL_NAME ($EMAIL)"
done

# Execute SQL commands
echo ""
echo "Inserting into SQL Server..."
{
  echo "USE TestDB;"
  echo "GO"
  echo "$SQL_COMMANDS"
  echo "GO"
  echo "SELECT TOP $COUNT id, name, email, created_at FROM dbo.users ORDER BY id DESC;"
  echo "GO"
} | docker-compose exec -T sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourPassword123!' -C

echo ""
echo "✓ Inserted $COUNT record(s)"
echo ""
echo "Waiting 2 seconds for CDC to capture changes..."
sleep 2

echo "Messages in Kafka (mssql.dbo.users topic):"
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic mssql.dbo.users \
  --timeout-ms 3000 \
  --max-messages 5 2>&1 | grep -v "ERROR\|Processed\|org.apache" || echo "(checking...)"
