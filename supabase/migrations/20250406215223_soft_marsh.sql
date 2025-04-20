/*
  # Add notification triggers and functions

  1. Changes
    - Add trigger for program real audience updates
    - Add trigger for badge unlocks
    - Add trigger for leaderboard updates
    - Add notification view with user info

  2. Security
    - Maintain existing RLS policies
*/

-- Function to create notification when program real audience is updated
CREATE OR REPLACE FUNCTION create_real_audience_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Get predictions for this program
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message
  )
  SELECT 
    p.user_id,
    'program',
    'Résultat disponible',
    'L''audience réelle de "' || (SELECT name FROM programs WHERE id = p.program_id) || '" est de ' || 
    NEW.real_audience || 'M. Votre précision : ' || p.calculated_accuracy || '% (' || p.calculated_score || ' points)'
  FROM predictions p
  WHERE p.program_id = NEW.id
  AND p.user_id IS NOT NULL;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for real audience updates with unique name
CREATE TRIGGER trigger_update_real_audience_notification
  AFTER UPDATE OF real_audience ON public.programs
  FOR EACH ROW
  WHEN (NEW.real_audience IS DISTINCT FROM OLD.real_audience)
  EXECUTE FUNCTION create_real_audience_notification();

-- Function to create notification for new badges
CREATE OR REPLACE FUNCTION create_badge_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Notification for first prediction
  IF NEW.total_score = 100 AND OLD.total_score < 100 THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez obtenu le badge "Premier Pronostic" !'
    );
  END IF;

  -- Notification for 1000 points
  IF NEW.total_score >= 1000 AND OLD.total_score < 1000 THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez obtenu le badge "Expert TV" !'
    );
  END IF;

  -- Notification for 90%+ precision
  IF NEW.precision_score >= 90 AND OLD.precision_score < 90 THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez obtenu le badge "Précision Extrême" !'
    );
  END IF;

  -- Notification for reaching top 3
  IF NEW.rank <= 3 AND OLD.rank > 3 THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez atteint le TOP 3 du classement !'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for badge notifications with unique name
DROP TRIGGER IF EXISTS trigger_badge_notification ON public.leaderboard;
CREATE TRIGGER trigger_badge_notification
  AFTER UPDATE OF total_score, precision_score, rank ON public.leaderboard
  FOR EACH ROW
  EXECUTE FUNCTION create_badge_notification();

-- Create view for notifications with user info
DROP VIEW IF EXISTS public.notifications_with_user;
CREATE VIEW public.notifications_with_user AS
SELECT 
  n.*,
  p.username,
  p.avatar_url
FROM public.notifications n
JOIN public.profiles p ON p.id = n.user_id
ORDER BY n.created_at DESC;

-- Grant access to the view
GRANT SELECT ON public.notifications_with_user TO authenticated;