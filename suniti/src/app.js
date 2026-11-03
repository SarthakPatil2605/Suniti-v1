import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.routes.js';
import customerRoutes from './routes/customer.routes.js';
import opportunityRoutes from './routes/opportunity.routes.js';
import taskRoutes from './routes/task.routes.js';
import adminRoutes from './routes/admin.routes.js';
import protectedRoutes from './routes/protected.routes.js';
import errorHandler from './middlewares/errorHandler.js';

export const createApp = () => {
  const app = express();

  // Core Middlewares
  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Healthcheck Route
  app.get('/api/health', (req, res) => {
    res.status(200).json({
      status: 'UP',
      service: 'Suniti Construction CRM API',
      timestamp: new Date().toISOString(),
    });
  });

  // Mount API Routers
  app.use('/api/auth', authRoutes);
  app.use('/api/customers', customerRoutes);
  app.use('/api/opportunities', opportunityRoutes);
  app.use('/api/tasks', taskRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api', protectedRoutes);

  // 404 Handler
  app.use((req, res) => {
    res.status(404).json({
      success: false,
      message: `Cannot ${req.method} ${req.originalUrl}`,
    });
  });

  // Centralized Error Handler
  app.use(errorHandler);

  return app;
};

export default createApp;
