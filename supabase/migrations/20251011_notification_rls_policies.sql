-- Enable RLS on notification tables
ALTER TABLE notification_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- NOTIFICATION TOPICS POLICIES
-- ============================================================================

-- Everyone can read active notification topics
CREATE POLICY "notification_topics_select_policy"
ON notification_topics
FOR SELECT
USING (is_active = true);

-- Only authenticated admins can insert/update/delete topics
CREATE POLICY "notification_topics_admin_policy"
ON notification_topics
FOR ALL
USING (
  auth.uid() IS NOT NULL 
  AND EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'role' = 'admin'
  )
);

-- ============================================================================
-- USER NOTIFICATION PREFERENCES POLICIES
-- ============================================================================

-- Users can read their own preferences
CREATE POLICY "user_notification_preferences_select_policy"
ON user_notification_preferences
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "user_notification_preferences_insert_policy"
ON user_notification_preferences
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "user_notification_preferences_update_policy"
ON user_notification_preferences
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own preferences
CREATE POLICY "user_notification_preferences_delete_policy"
ON user_notification_preferences
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- USER FCM TOKENS POLICIES
-- ============================================================================

-- Users can read their own tokens
CREATE POLICY "user_fcm_tokens_select_policy"
ON user_fcm_tokens
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "user_fcm_tokens_insert_policy"
ON user_fcm_tokens
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "user_fcm_tokens_update_policy"
ON user_fcm_tokens
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "user_fcm_tokens_delete_policy"
ON user_fcm_tokens
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: Triggers are already created in your schema, so we don't recreate them

-- ============================================================================
-- INDEXES FOR PERFORMANCE (if not already exists)
-- ============================================================================

-- These indexes should already exist from your schema, but adding IF NOT EXISTS for safety
CREATE INDEX IF NOT EXISTS idx_user_notification_preferences_user_topic 
ON user_notification_preferences(user_id, topic_id);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_active 
ON user_fcm_tokens(user_id, is_active);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE notification_topics IS 'Available notification topics/categories that users can subscribe to';
COMMENT ON TABLE user_notification_preferences IS 'User preferences for each notification topic (enabled/disabled)';
COMMENT ON TABLE user_fcm_tokens IS 'FCM push notification tokens for each user device';

COMMENT ON COLUMN notification_topics.icon IS 'Emoji or icon identifier for the topic';
COMMENT ON COLUMN notification_topics.display_order IS 'Sort order for displaying topics in UI';
COMMENT ON COLUMN notification_topics.is_default IS 'Whether new users should be subscribed to this topic by default';
COMMENT ON COLUMN user_fcm_tokens.last_used_at IS 'Last time this token was used (updated on each app launch)';
