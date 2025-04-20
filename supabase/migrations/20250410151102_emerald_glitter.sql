/*
  # Add badge system tables and functions

  1. New Tables
    - badges: Store badge definitions
      - id (uuid, primary key)
      - name (text)
      - description (text)
      - category (text): performance, regularity, engagement
      - criteria (jsonb): requirements to earn badge
      - icon_url (text)
      - created_at (timestamptz)
      
    - user_badges: Store earned badges
      - id (uuid, primary key)
      - user_id (uuid, references auth.users)
      - badge_id (uuid, references badges)
      - earned_at (timestamptz)
      - progress (numeric): percentage complete
      
  2. Security
    - Enable RLS
    - Add policies for badge management
*/

-- Create enum for badge categories
CREATE TYPE badge_category AS ENUM ('performance', 'regularity', 'engagement');

-- Create badges table
CREATE TABLE public.badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  category badge_category NOT NULL,
  criteria jsonb NOT NULL,
  icon_url text,
  created_at timestamptz DEFAULT now()
);

-- Create user_badges table
CREATE TABLE public.user_badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  badge_id uuid REFERENCES badges(id) ON DELETE CASCADE NOT NULL,
  earned_at timestamptz DEFAULT now(),
  progress numeric DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  UNIQUE(user_id, badge_id)
);

-- Enable RLS
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Anyone can view badges"
  ON badges FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Users can view their own badges"
  ON user_badges FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Create view for user badge progress
CREATE VIEW public.user_badge_progress AS
SELECT 
  ub.user_id,
  b.id as badge_id,
  b.name,
  b.description,
  b.category,
  b.icon_url,
  ub.earned_at,
  ub.progress,
  CASE WHEN ub.earned_at IS NOT NULL THEN true ELSE false END as is_earned
FROM badges b
LEFT JOIN user_badges ub ON b.id = ub.badge_id;

-- Grant access to the view
GRANT SELECT ON public.user_badge_progress TO authenticated;

-- Insert default badges
INSERT INTO badges (name, description, category, criteria, icon_url) VALUES
-- Performance badges
('Top Chef (Or)', 'Réaliser une prédiction exacte à 0,1 % près', 'performance', 
  '{"type": "accuracy", "threshold": 99.9, "count": 1}'::jsonb,
  'https://i.postimg.cc/QxWJ4YRY/top-chef-or.png'),
  
('Hit Machine (Argent)', 'Réaliser 10 prédictions avec plus de 95% de précision', 'performance',
  '{"type": "accuracy", "threshold": 95, "count": 10}'::jsonb,
  'https://i.postimg.cc/Kj8tXhH6/hit-machine-argent.png'),
  
('Graine de Star (Bronze)', 'Réaliser 5 prédictions avec plus de 90% de précision', 'performance',
  '{"type": "accuracy", "threshold": 90, "count": 5}'::jsonb,
  'https://i.postimg.cc/QdqwLWGK/graine-de-star-bronze.png'),

-- Regularity badges
('Objectif Top Chef', 'Faire des pronostics chaque semaine pendant 4 semaines consécutives', 'regularity',
  '{"type": "weekly_streak", "weeks": 4}'::jsonb,
  'https://i.postimg.cc/RZp4GYLW/objectif-top-chef.png'),
  
('Un diner presque parfait', 'Effectuer 20 pronostics dans un seul mois', 'regularity',
  '{"type": "monthly_predictions", "count": 20}'::jsonb,
  'https://i.postimg.cc/QMJvNpGK/un-diner-presque-parfait.png'),

-- Engagement badges
('Nouvelle Star', 'Effectuer son premier pronostic', 'engagement',
  '{"type": "first_prediction"}'::jsonb,
  'https://i.postimg.cc/RVHBGXyY/nouvelle-star.png'),
  
('Destination X', 'Pronostiquer sur 5 genres différents d''émissions TV', 'engagement',
  '{"type": "unique_genres", "count": 5}'::jsonb,
  'https://i.postimg.cc/3xKQf8Yh/destination-x.png');

-- Function to check and award badges
CREATE OR REPLACE FUNCTION check_and_award_badges()
RETURNS TRIGGER AS $$
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
  WHERE p.user_id = NEW.user_id;

  -- Check each badge
  FOR badge IN SELECT * FROM badges
  LOOP
    -- Skip if already earned
    CONTINUE WHEN EXISTS (
      SELECT 1 FROM user_badges 
      WHERE user_id = NEW.user_id 
      AND badge_id = badge.id 
      AND earned_at IS NOT NULL
    );

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
        WHERE user_id = NEW.user_id
        AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
        AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE);

      WHEN 'weekly_streak' THEN
        WITH weekly_predictions AS (
          SELECT 
            DATE_TRUNC('week', created_at) as week,
            COUNT(*) as predictions
          FROM predictions
          WHERE user_id = NEW.user_id
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
    VALUES (NEW.user_id, badge.id, progress)
    ON CONFLICT (user_id, badge_id) 
    DO UPDATE SET 
      progress = EXCLUDED.progress,
      earned_at = CASE 
        WHEN EXCLUDED.progress >= 100 AND user_badges.earned_at IS NULL 
        THEN now() 
        ELSE user_badges.earned_at 
      END;

    -- Create notification for newly earned badge
    IF progress >= 100 THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message
      ) VALUES (
        NEW.user_id,
        'badge',
        'Nouveau badge débloqué !',
        'Félicitations ! Vous avez obtenu le badge "' || badge.name || '" !'
      );
    END IF;

  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for badge checks
CREATE TRIGGER check_badges_after_prediction
  AFTER INSERT OR UPDATE OF calculated_accuracy ON predictions
  FOR EACH ROW
  EXECUTE FUNCTION check_and_award_badges();