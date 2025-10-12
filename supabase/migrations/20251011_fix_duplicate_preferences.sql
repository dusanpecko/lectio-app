-- Fix Duplicate User Notification Preferences
-- This removes duplicate entries keeping only the most recent one

-- Step 1: Find and display duplicates (for debugging)
SELECT user_id, topic_id, COUNT(*) as count
FROM user_notification_preferences
GROUP BY user_id, topic_id
HAVING COUNT(*) > 1;

-- Step 2: Delete duplicates, keeping only the most recent (highest id or latest updated_at)
DELETE FROM user_notification_preferences a
USING user_notification_preferences b
WHERE a.id < b.id  -- Keep the one with higher ID (more recent)
  AND a.user_id = b.user_id
  AND a.topic_id = b.topic_id;

-- Step 3: Verify no duplicates remain
SELECT user_id, topic_id, COUNT(*) as count
FROM user_notification_preferences
GROUP BY user_id, topic_id
HAVING COUNT(*) > 1;

-- Expected: No rows (all duplicates removed)

-- Step 4: Verify the unique constraint exists
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'user_notification_preferences'
  AND constraint_name = 'user_notification_preferences_user_id_topic_id_key';

-- Expected: One row with constraint_type = 'UNIQUE'
