import pkg from 'pg';
import dotenv from 'dotenv';
import { hashPassword } from '../src/utils/password.js';

dotenv.config();
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function seedUsers() {
  try {
    console.log('Generating secure password hashes...');
    const hashedPassword1 = await hashPassword('password123');
    const hashedPassword2 = await hashPassword('adminpassword123');

    console.log('Updating database with properly hashed passwords...');
    
    // Clear existing or upsert employees
    await pool.query(`
      INSERT INTO employees (name, email, password_hash, role) 
      VALUES 
        ('Sandeep Kumar', 'sandeep@suniti.com', $1, 'SALES_REP'),
        ('Admin User', 'admin@suniti.com', $2, 'ADMIN')
      ON CONFLICT (email) 
      DO UPDATE SET password_hash = EXCLUDED.password_hash, role = EXCLUDED.role;
    `, [hashedPassword1, hashedPassword2]);

    console.log('Users seeded successfully with valid bcrypt hashes!');
    process.exit(0);
  } catch (err) {
    console.error('Seeding failed:', err);
    process.exit(1);
  }
}

seedUsers();