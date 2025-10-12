-- RLS Policy for Users Table
-- This allows authenticated users to read their own user record
-- Required for notification preferences queries that reference users table

-- Enable RLS on users table (if not already enabled)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Service role has full access to users" ON users;

-- Policy: Users can read their own data
CREATE POLICY "Users can view their own profile"
ON users
FOR SELECT
USING (auth.uid() = id);

-- Policy: Users can update their own data
CREATE POLICY "Users can update their own profile"
ON users
FOR UPDATE
USING (auth.uid() = id);

-- Policy: Service role can do everything (pre admin operations)
CREATE POLICY "Service role has full access to users"
ON users
FOR ALL
USING (auth.role() = 'service_role');

-- Verify policies
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;
