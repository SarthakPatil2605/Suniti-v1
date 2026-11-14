import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import prisma, { testDatabaseConnection } from './config/prisma.js';

// Route imports
import authRoutes from './routes/auth.routes.js';
import employeeRoutes from './routes/employee.routes.js';
import customerRoutes from './routes/customer.routes.js';
import opportunityRoutes from './routes/opportunity.routes.js';
import leadNoteRoutes from './routes/leadNote.routes.js';
import managerRoutes from './routes/manager.routes.js';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// ==========================================
// MIDDLEWARES
// ==========================================

// 1. CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
app.use(cors(corsOptions));

// 2. Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 3. Request logger (concise development logging)
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (req.originalUrl !== '/health') {
      console.log(
        `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} - ${res.statusCode} (${duration}ms)`
      );
    }
  });
  next();
});

// ==========================================
// SYSTEM & HEALTH CHECK ROUTES
// ==========================================

app.get('/', (req, res) => {
  res.status(200).json({
    app: 'Suniti Construction CRM Backend',
    version: '1.0.0',
    status: 'online',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', async (req, res) => {
  const dbStatus = await testDatabaseConnection();

  const responsePayload = {
    status: dbStatus.ok ? 'healthy' : 'degraded',
    uptime: `${Math.floor(process.uptime())}s`,
    database: dbStatus,
    timestamp: new Date().toISOString(),
    environment: NODE_ENV,
  };

  res.status(dbStatus.ok ? 200 : 503).json(responsePayload);
});

// ==========================================
// API ROUTE PLACEHOLDERS
// ==========================================

app.use('/api/auth', authRoutes);
app.use('/api/employees', employeeRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/admin/customers', customerRoutes); // Supports /api/admin/customers/:id/blocklist
app.use('/api/opportunities', opportunityRoutes);
app.use('/api/lead-notes', leadNoteRoutes);
app.use('/api/tasks', leadNoteRoutes); // Convenient alias for tasks
app.use('/api/manager', managerRoutes); // Manager workload, alerts, audit, & analytics

// API root summary
app.get('/api', (req, res) => {
  res.status(200).json({
    message: 'Welcome to Suniti Construction CRM API',
    endpoints: {
      auth: '/api/auth',
      employees: '/api/employees',
      customers: '/api/customers',
      opportunities: '/api/opportunities',
      lead_notes: '/api/lead-notes',
      tasks: '/api/tasks',
      manager: '/api/manager',
      health: '/health',
    },
  });
});

// ==========================================
// 404 NOT FOUND HANDLER
// ==========================================

app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// ==========================================
// GLOBAL ERROR HANDLER
// ==========================================

app.use((err, req, res, next) => {
  console.error('Unhandled Application Error:', err);

  // Malformed JSON payload
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Invalid JSON payload received',
    });
  }

  // Prisma: Unique constraint violation (e.g., duplicate email)
  if (err.code === 'P2002') {
    const fields = err.meta?.target ? err.meta.target.join(', ') : 'field';
    return res.status(409).json({
      error: 'Conflict',
      message: `A record with this ${fields} already exists.`,
    });
  }

  // Prisma: Record not found
  if (err.code === 'P2025') {
    return res.status(404).json({
      error: 'Not Found',
      message: err.meta?.cause || 'The requested record was not found.',
    });
  }

  // Prisma: Foreign key constraint failure
  if (err.code === 'P2003') {
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Referenced foreign key entity does not exist.',
    });
  }

  // JWT Errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid authorization token',
    });
  }
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Authorization token has expired',
    });
  }

  // General server error
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: err.name || 'Internal Server Error',
    message: err.message || 'An unexpected error occurred.',
    ...(NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ==========================================
// SERVER INITIALIZATION & GRACEFUL SHUTDOWN
// ==========================================

const server = app.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`🚀 Suniti Construction CRM Backend Running`);
  console.log(`📡 URL: http://localhost:${PORT}`);
  console.log(`🩺 Health check: http://localhost:${PORT}/health`);
  console.log(`🛠️ Environment: ${NODE_ENV}`);
  console.log(`====================================================`);
});

const handleShutdown = async (signal) => {
  console.log(`\nReceived ${signal}. Shutting down gracefully...`);
  server.close(async () => {
    console.log('HTTP server closed.');
    try {
      await prisma.$disconnect();
      console.log('Prisma client disconnected.');
    } catch (dbErr) {
      console.error('Error disconnecting Prisma client:', dbErr);
    }
    process.exit(0);
  });

  // Force shutdown after 10s timeout
  setTimeout(() => {
    console.error('Forced shutdown due to timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => handleShutdown('SIGINT'));
process.on('SIGTERM', () => handleShutdown('SIGTERM'));

export default app;
