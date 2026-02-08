# Database Plugin Template

Template for creating MCP plugins that connect to databases.

## Supported Databases

- PostgreSQL (recommended - see `postgresql-manager` plugin)
- MySQL/MariaDB
- MongoDB
- SQLite
- Any database with a Node.js driver

## Quick Start

1. **Copy template**
   ```bash
   cp -r plugins/templates/database plugins/my-db-plugin
   cd plugins/my-db-plugin
   ```

2. **Install database driver**
   ```bash
   # PostgreSQL
   npm install pg

   # MySQL
   npm install mysql2

   # MongoDB
   npm install mongodb

   # SQLite
   npm install better-sqlite3
   ```

3. **Configure connection**
   - Copy `.env.example` to `.env`
   - Update with your database credentials

4. **Implement database client**
   - Edit `index.js`
   - Uncomment and implement `getClient()` for your database
   - Update query methods

5. **Test**
   ```bash
   npm install
   npm start
   ```

## Database-Specific Implementation

### PostgreSQL Example

```javascript
import pg from 'pg';
const { Client } = pg;

async getClient() {
  if (!this.client) {
    this.client = new Client({
      host: DB_HOST,
      port: DB_PORT,
      database: DB_NAME,
      user: DB_USER,
      password: DB_PASSWORD,
    });
    await this.client.connect();
  }
  return this.client;
}

async handleExecuteQuery(args) {
  const client = await this.getClient();
  const result = await client.query(args.query, args.params || []);
  return {
    content: [{
      type: 'text',
      text: `Rows: ${result.rowCount}\n${JSON.stringify(result.rows, null, 2)}`
    }]
  };
}
```

### MySQL Example

```javascript
import mysql from 'mysql2/promise';

async getClient() {
  if (!this.client) {
    this.client = await mysql.createConnection({
      host: DB_HOST,
      port: DB_PORT,
      database: DB_NAME,
      user: DB_USER,
      password: DB_PASSWORD,
    });
  }
  return this.client;
}
```

### MongoDB Example

```javascript
import { MongoClient } from 'mongodb';

async getClient() {
  if (!this.client) {
    const mongoClient = new MongoClient(process.env.DB_CONNECTION_STRING);
    await mongoClient.connect();
    this.client = mongoClient.db(DB_NAME);
  }
  return this.client;
}

async handleGetTableData(args) {
  const db = await this.getClient();
  const collection = db.collection(args.table);
  const docs = await collection.find({}).limit(args.limit || 100).toArray();
  return {
    content: [{
      type: 'text',
      text: JSON.stringify(docs, null, 2)
    }]
  };
}
```

## Security Best Practices

1. **Never commit credentials**
   - Add `.env` to `.gitignore`
   - Use environment variables

2. **Use parameterized queries**
   ```javascript
   // ✅ Good
   await client.query('SELECT * FROM users WHERE id = $1', [userId]);

   // ❌ Bad (SQL injection risk)
   await client.query(`SELECT * FROM users WHERE id = ${userId}`);
   ```

3. **Limit query permissions**
   - Use read-only database user when possible
   - Grant minimum required permissions

4. **Connection pooling**
   - Use connection pools for production
   - Close connections properly

## Examples

See existing database plugins:
- `plugins/postgresql-manager/` - Full PostgreSQL implementation

## License

MIT
