/*
  # Create leaderboard view with profiles

  1. Changes
    - Drop existing view if it exists
    - Create view joining leaderboard and profiles
    - Add function for prediction count
    - Grant proper access to view

  2. Security
    - Grant SELECT access to authenticated users
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.leaderboard_with_profiles;

-- Create view for leaderboard with profiles
CREATE VIEW public.leaderboard_with_profiles AS
SELECT 
  l.id,
  l.user_id,
  l.total_score,
  l.precision_score,
  l.rank,
  l.updated_at,
  p.username,
  p.avatar_url
FROM public.leaderboard l
JOIN public.profiles p ON p.id = l.user_id;

-- Grant access to the view
GRANT SELECT ON public.leaderboard_with_profiles TO authenticated;

-- Create function to get user prediction count
CREATE OR REPLACE FUNCTION public.get_user_prediction_count(user_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer
    FROM public.predictions
    WHERE user_id = user_uuid
  );
END;
$$ LANGUAGE plpgsql;