/*
  # Recalculate badges for all users

  1. Changes
    - Add function to recalculate badge progress for all users
    - Update existing badge progress
    - Trigger badge notifications for newly earned badges

  2. Security
    - Maintain existing RLS policies
*/

-- Function to recalculate badge progress for a user
CREATE OR REPLACE FUNCTION recalculate_user_badges(user_uuid uuid)
RETURNS void AS $$
DECLARE
  badge record;
  user_stats record;
  progress numeric;
BEGIN
  -- Get user statistics
  SELECT 
    COUNT(*) as total_predictions,
    COUNT(DISTINCT genre) as unique_genres,
    AVG(calculated_accuracy) as avg_accuracy,
    COUNT(*) FILTER (WHERE calculated_accuracy >= 99.9) as perfect_predictions,
    COUNT(*) FILTER (WHERE calculated_accuracy >= 95) as excellent_predictions,
    COUNT(*) FILTER (WHERE calculated_accuracy >= 90) as good_predictions
  INTO user_stats
  FROM predictions p
  JOIN programs pr ON p.program_id = pr.id
  WHERE p.user_id = user_uuid;

  -- Check each badge
  FOR badge IN SELECT * FROM badges
  LOOP
    -- Calculate progress based on badge type
    CASE badge.criteria->>'type'
      WHEN 'accuracy' THEN
        IF badge.criteria->>'threshold' = '99.9' THEN
          progress := LEAST(100, (user_stats.perfect_predictions::numeric / (badge.criteria->>'count')::numeric) * 100);
        ELSIF badge.criteria->>'threshold' = '95' THEN
          progress := LEAST(100, (user_stats.excellent_predictions::numeric / (badge.criteria->>'count')::numeric) * 100);
        ELSIF badge.criteria->>'threshold' = '90' THEN
          progress := LEAST(100, (user_stats.good_predictions::numeric / (badge.criteria->>'count')::numeric) * 100);
        END IF;

      WHEN 'first_prediction' THEN
        progress := CASE WHEN user_stats.total_predictions > 0 THEN 100 ELSE 0 END;

      WHEN 'unique_genres' THEN
        progress := LEAST(100, (user_stats.unique_genres::numeric / (badge.criteria->>'count')::numeric) * 100);

      WHEN 'monthly_predictions' THEN
        SELECT LEAST(100, (COUNT(*)::numeric / (badge.criteria->>'count')::numeric) * 100)
        INTO progress
        FROM predictions
        WHERE user_id = user_uuid
        AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
        AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE);

      WHEN 'weekly_streak' THEN
        WITH weekly_predictions AS (
          SELECT 
            DATE_TRUNC('week', created_at) as week,
            COUNT(*) as predictions
          FROM predictions
          WHERE user_id = user_uuid
          GROUP BY week
          HAVING COUNT(*) > 0
          ORDER BY week DESC
        )
        SELECT LEAST(100, (COUNT(*)::numeric / (badge.criteria->>'weeks')::numeric) * 100)
        INTO progress
        FROM (
          SELECT week, 
            week = LAG(week) OVER (ORDER BY week) + interval '1 week' as consecutive
          FROM weekly_predictions
        ) w
        WHERE consecutive;
    END CASE;

    -- Insert or update progress
    INSERT INTO user_badges (user_id, badge_id, progress)
    VALUES (user_uuid, badge.id, COALESCE(progress, 0))
    ON CONFLICT (user_id, badge_id) 
    DO UPDATE SET 
      progress = EXCLUDED.progress,
      earned_at = CASE 
        WHEN EXCLUDED.progress >= 100 AND user_badges.earned_at IS NULL 
        THEN now() 
        ELSE user_badges.earned_at 
      END;

  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recalculate badges for all existing users
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM auth.users
  LOOP
    PERFORM recalculate_user_badges(user_record.id);
  END LOOP;
END $$;