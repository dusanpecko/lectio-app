-- Debug: Check all notification topics and user preferences
-- Run this in Supabase SQL Editor

-- 1. Check how many topics exist and which are active
SELECT 
  id,
  name_sk,
  is_active,
  display_order,
  category
FROM notification_topics
ORDER BY display_order;

-- 2. Count active vs inactive topics
SELECT 
  is_active,
  COUNT(*) as count
FROM notification_topics
GROUP BY is_active;

-- 3. Check user preferences with topic names
SELECT 
  p.id,
  p.user_id,
  p.topic_id,
  t.name_sk as topic_name,
  p.is_enabled,
  p.updated_at
FROM user_notification_preferences p
LEFT JOIN notification_topics t ON p.topic_id = t.id
WHERE p.user_id = 'd0d8b50c-48a2-41c7-9d8d-a0b87422438'  -- Your user ID from screenshot
ORDER BY p.updated_at DESC;

-- 4. Check for duplicate preferences
SELECT 
  user_id, 
  topic_id, 
  COUNT(*) as count
FROM user_notification_preferences
WHERE user_id = 'd0d8b50c-48a2-41c7-9d8d-a0b87422438'
GROUP BY user_id, topic_id
HAVING COUNT(*) > 1;
