import fs from 'fs';
import path from 'path';
import pkg from 'pg';
import dotenv from 'dotenv';

dotenv.config();
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL, // Uses your Supabase connection string
  ssl: { 
    rejectUnauthorized: false // Required for Supabase cloud connections
  }
});

async function runMigration() {
  try {
    const schemaPath = path.join(process.cwd(), 'schema.sql');
    const sqlQuery = fs.readFileSync(schemaPath, 'utf8');

    console.log('Running schema migration on Supabase...');
    await pool.query(sqlQuery);
    console.log('Migration completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

runMigration();