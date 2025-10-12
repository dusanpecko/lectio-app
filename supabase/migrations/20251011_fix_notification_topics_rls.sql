-- Fix RLS policy for notification_topics that was causing "permission denied for table users" error
-- The admin policy was trying to access auth.users table which requires additional permissions

-- Drop the problematic admin policy
DROP POLICY IF EXISTS "notification_topics_admin_policy" ON notification_topics;

-- Create a simpler admin policy that doesn't check auth.users
-- This policy will allow only service_role to modify topics, regular users can only read
CREATE POLICY "notification_topics_admin_policy"
ON notification_topics
FOR ALL
USING (
  -- Only allow modifications if user has service_role (backend/admin operations)
  -- Regular users will be blocked by this policy for INSERT/UPDATE/DELETE
  -- But SELECT will work via the separate select policy
  false
);

-- Alternatively, if you want to allow authenticated users to suggest topics
-- (but this is usually not needed), you can use:
-- USING (auth.role() = 'service_role');

-- The SELECT policy remains unchanged and will work for all users:
-- "notification_topics_select_policy" allows reading active topics
