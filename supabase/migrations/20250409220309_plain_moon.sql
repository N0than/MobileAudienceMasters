/*
  # Add predictions count to leaderboard view

  1. Changes
    - Drop existing leaderboard view
    - Create new view that includes predictions count
    - Add proper ordering and null handling

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing view
DROP VIEW IF EXISTS public.leaderboard_with_profiles;

-- Create improved view that includes predictions count
CREATE VIEW public.leaderboard_with_profiles AS
SELECT 
  l.id,
  l.user_id,
  l.total_score,
  l.precision_score,
  l.rank,
  l.updated_at,
  p.username,
  p.avatar_url,
  COALESCE((
    SELECT COUNT(*)
    FROM public.predictions pr
    WHERE pr.user_id = l.user_id
  ), 0) as predictions_count
FROM public.leaderboard l
JOIN public.profiles p ON p.id = l.user_id
ORDER BY 
  l.total_score DESC,
  l.precision_score DESC,
  l.updated_at ASC;

-- Grant access to the view
GRANT SELECT ON public.leaderboard_with_profiles TO authenticated;