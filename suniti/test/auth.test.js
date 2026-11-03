import test, { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, comparePassword } from '../src/utils/password.js';
import { signToken, verifyJwt } from '../src/utils/jwt.js';
import { verifyToken, verifyAdmin, verifyEmployee } from '../src/middlewares/auth.middleware.js';

describe('1. Password Hashing & Comparison (bcrypt)', () => {
  it('should hash a password and correctly verify matches and non-matches', async () => {
    const rawPassword = 'SecurePassword123!';
    const hash = await hashPassword(rawPassword);

    assert.ok(hash.startsWith('$2'), 'Bcrypt hash should start with $2');
    assert.notEqual(hash, rawPassword, 'Hashed password should not equal raw password');

    const isValid = await comparePassword(rawPassword, hash);
    assert.equal(isValid, true, 'Valid password comparison should be true');

    const isInvalid = await comparePassword('WrongPassword!', hash);
    assert.equal(isInvalid, false, 'Invalid password comparison should be false');
  });
});

describe('2. JWT Signing & Token Structure', () => {
  it('should sign a JWT token containing employee_id, name, and role', () => {
    const mockEmployee = {
      employee_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      name: 'Rahul Sharma',
      role: 'ADMIN',
      email: 'rahul.admin@suniticonstruction.com',
    };

    const token = signToken(mockEmployee);
    assert.ok(typeof token === 'string', 'Token should be a string');

    const decoded = verifyJwt(token);
    assert.equal(decoded.employee_id, mockEmployee.employee_id);
    assert.equal(decoded.name, mockEmployee.name);
    assert.equal(decoded.role, mockEmployee.role);
    assert.equal(decoded.email, mockEmployee.email);
  });
});

describe('3. Middleware: verifyToken', () => {
  it('should reject request missing Authorization header with 401', () => {
    const req = { headers: {} };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status: (code) => {
        statusSent = code;
        return {
          json: (data) => {
            jsonSent = data;
          },
        };
      },
    };
    let nextCalled = false;

    verifyToken(req, res, () => {
      nextCalled = true;
    });

    assert.equal(statusSent, 401);
    assert.equal(jsonSent.success, false);
    assert.equal(nextCalled, false);
  });

  it('should reject request with invalid bearer token with 401', () => {
    const req = { headers: { authorization: 'Bearer invalid.mock.jwt' } };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status: (code) => {
        statusSent = code;
        return {
          json: (data) => {
            jsonSent = data;
          },
        };
      },
    };
    let nextCalled = false;

    verifyToken(req, res, () => {
      nextCalled = true;
    });

    assert.equal(statusSent, 401);
    assert.equal(jsonSent.message, 'Invalid authentication token.');
    assert.equal(nextCalled, false);
  });

  it('should decode valid JWT and attach req.user then call next()', () => {
    const token = signToken({
      employee_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      name: 'Priya Patil',
      role: 'SALES_REP',
    });

    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = {};
    let nextCalled = false;

    verifyToken(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
    assert.ok(req.user);
    assert.equal(req.user.name, 'Priya Patil');
    assert.equal(req.user.role, 'SALES_REP');
  });
});

describe('4. Middleware: verifyAdmin', () => {
  it('should allow user with role === "ADMIN"', () => {
    const req = { user: { role: 'ADMIN', name: 'Admin User' } };
    const res = {};
    let nextCalled = false;

    verifyAdmin(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
  });

  it('should deny user with role === "SALES_REP" with 403 Forbidden', () => {
    const req = { user: { role: 'SALES_REP', name: 'Sales Rep User' } };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status: (code) => {
        statusSent = code;
        return {
          json: (data) => {
            jsonSent = data;
          },
        };
      },
    };
    let nextCalled = false;

    verifyAdmin(req, res, () => {
      nextCalled = true;
    });

    assert.equal(statusSent, 403);
    assert.equal(jsonSent.success, false);
    assert.match(jsonSent.message, /Requires ADMIN role/);
    assert.equal(nextCalled, false);
  });
});

describe('5. Middleware: verifyEmployee', () => {
  it('should allow user with role === "ADMIN"', () => {
    const req = { user: { role: 'ADMIN' } };
    const res = {};
    let nextCalled = false;

    verifyEmployee(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
  });

  it('should allow user with role === "SALES_REP"', () => {
    const req = { user: { role: 'SALES_REP' } };
    const res = {};
    let nextCalled = false;

    verifyEmployee(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
  });

  it('should deny user with unknown or unauthorized role with 403 Forbidden', () => {
    const req = { user: { role: 'CONTRACTOR' } };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status: (code) => {
        statusSent = code;
        return {
          json: (data) => {
            jsonSent = data;
          },
        };
      },
    };
    let nextCalled = false;

    verifyEmployee(req, res, () => {
      nextCalled = true;
    });

    assert.equal(statusSent, 403);
    assert.equal(jsonSent.success, false);
    assert.equal(nextCalled, false);
  });
});
