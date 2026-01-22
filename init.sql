-- Database initialization script for n8n Backend Builder
-- Creates all necessary tables and initial data

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. USERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- =====================================================
-- 2. TODOS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT false,
    due_date DATE,
    priority VARCHAR(20) DEFAULT 'medium',
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_todos_user_id ON todos(user_id);
CREATE INDEX idx_todos_completed ON todos(completed);
CREATE INDEX idx_todos_due_date ON todos(due_date);

-- =====================================================
-- 3. REQUEST LOGS TABLE (Observability)
-- =====================================================
CREATE TABLE IF NOT EXISTS request_logs (
    id SERIAL PRIMARY KEY,
    request_id UUID DEFAULT uuid_generate_v4(),
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    ip_address VARCHAR(50),
    user_agent TEXT,
    status_code INTEGER,
    response_time INTEGER, -- in milliseconds
    error_message TEXT,
    request_body JSONB,
    response_body JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for analytics queries
CREATE INDEX idx_logs_endpoint ON request_logs(endpoint);
CREATE INDEX idx_logs_created_at ON request_logs(created_at);
CREATE INDEX idx_logs_status_code ON request_logs(status_code);
CREATE INDEX idx_logs_user_id ON request_logs(user_id);

-- =====================================================
-- 4. RATE LIMITS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS rate_limits (
    id SERIAL PRIMARY KEY,
    identifier VARCHAR(255) NOT NULL, -- IP or user_id
    endpoint VARCHAR(255) NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    window_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_rate_limits_identifier ON rate_limits(identifier);
CREATE INDEX idx_rate_limits_window_start ON rate_limits(window_start);

-- =====================================================
-- 5. SCHEMAS TABLE (For dynamic model generation)
-- =====================================================
CREATE TABLE IF NOT EXISTS schemas (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(255) UNIQUE NOT NULL,
    schema_definition JSONB NOT NULL,
    table_created BOOLEAN DEFAULT false,
    endpoints_created BOOLEAN DEFAULT false,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_schemas_model_name ON schemas(model_name);

-- =====================================================
-- 6. API KEYS TABLE (For future API key auth)
-- =====================================================
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);

-- =====================================================
-- 7. INSERT DEMO DATA
-- =====================================================

-- Insert demo users
-- Password for all demo users: "demo123"
-- Hash generated with: bcrypt with 10 rounds
INSERT INTO users (username, email, password_hash, role) VALUES
('demo', 'demo@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'admin'),
('john', 'john@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'user'),
('jane', 'jane@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'user')
ON CONFLICT (username) DO NOTHING;

-- Insert sample todos
INSERT INTO todos (title, description, completed, due_date, priority, user_id) VALUES
('Setup n8n backend', 'Configure n8n with PostgreSQL and Docker', true, '2026-01-20', 'high', 1),
('Build authentication workflow', 'Implement JWT-based authentication', true, '2026-01-21', 'high', 1),
('Create CRUD endpoints', 'Build Create, Read, Update, Delete workflows', false, '2026-01-25', 'medium', 1),
('Add rate limiting', 'Implement rate limiting middleware', false, '2026-01-28', 'medium', 1),
('Write documentation', 'Create comprehensive README and API docs', false, '2026-01-30', 'low', 1),
('Learn n8n basics', 'Complete n8n tutorial', false, '2026-01-23', 'medium', 2),
('Test API endpoints', 'Use Postman to test all endpoints', false, '2026-01-26', 'high', 2)
ON CONFLICT DO NOTHING;

-- Insert sample schema
INSERT INTO schemas (model_name, schema_definition, table_created, created_by) VALUES
('Todo', '{
  "fields": {
    "title": {"type": "string", "required": true, "maxLength": 255},
    "description": {"type": "text", "required": false},
    "completed": {"type": "boolean", "default": false},
    "due_date": {"type": "date", "required": false},
    "priority": {"type": "string", "enum": ["low", "medium", "high"], "default": "medium"}
  }
}'::jsonb, true, 1)
ON CONFLICT (model_name) DO NOTHING;

-- =====================================================
-- 8. CREATE VIEWS FOR ANALYTICS
-- =====================================================

-- View: API usage statistics
CREATE OR REPLACE VIEW v_api_usage_stats AS
SELECT 
    endpoint,
    method,
    COUNT(*) as total_requests,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(response_time)::numeric(10,2) as avg_response_time_ms,
    MAX(response_time) as max_response_time_ms,
    MIN(response_time) as min_response_time_ms,
    COUNT(CASE WHEN status_code >= 200 AND status_code < 300 THEN 1 END) as success_count,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END) as error_count,
    (COUNT(CASE WHEN status_code >= 200 AND status_code < 300 THEN 1 END)::float / 
     NULLIF(COUNT(*), 0) * 100)::numeric(5,2) as success_rate_percent
FROM request_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY endpoint, method
ORDER BY total_requests DESC;

-- View: Recent errors
CREATE OR REPLACE VIEW v_recent_errors AS
SELECT 
    id,
    endpoint,
    method,
    status_code,
    error_message,
    user_id,
    created_at
FROM request_logs
WHERE status_code >= 400
    AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 100;

-- View: User activity
CREATE OR REPLACE VIEW v_user_activity AS
SELECT 
    u.id,
    u.username,
    u.role,
    COUNT(DISTINCT rl.id) as total_requests,
    COUNT(DISTINCT DATE(rl.created_at)) as active_days,
    MAX(rl.created_at) as last_activity,
    COUNT(t.id) as total_todos,
    COUNT(CASE WHEN t.completed THEN 1 END) as completed_todos
FROM users u
LEFT JOIN request_logs rl ON u.id = rl.user_id
LEFT JOIN todos t ON u.id = t.user_id
GROUP BY u.id, u.username, u.role
ORDER BY total_requests DESC;

-- =====================================================
-- 9. CREATE FUNCTIONS
-- =====================================================

-- Function: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_todos_updated_at BEFORE UPDATE ON todos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_schemas_updated_at BEFORE UPDATE ON schemas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function: Clean old rate limit records
CREATE OR REPLACE FUNCTION cleanup_old_rate_limits()
RETURNS void AS $$
BEGIN
    DELETE FROM rate_limits 
    WHERE window_start < NOW() - INTERVAL '2 hours';
END;
$$ LANGUAGE plpgsql;

-- Function: Clean old logs (keep 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_logs()
RETURNS void AS $$
BEGIN
    DELETE FROM request_logs 
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. GRANT PERMISSIONS
-- =====================================================

-- Grant all privileges to n8n user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO n8n;

-- =====================================================
-- INITIALIZATION COMPLETE
-- =====================================================

-- Display summary
DO $$
DECLARE
    user_count INTEGER;
    todo_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COUNT(*) INTO todo_count FROM todos;
    
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Database initialization completed successfully!';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Users created: %', user_count;
    RAISE NOTICE 'Sample todos: %', todo_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Demo credentials:';
    RAISE NOTICE '  Username: demo';
    RAISE NOTICE '  Password: demo123';
    RAISE NOTICE '  Role: admin';
    RAISE NOTICE '================================================';
END $$;