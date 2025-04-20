/*
  # Update leaderboard view to use predictions_with_accuracy

  1. Changes
    - Update leaderboard view to calculate predictions count from predictions_with_accuracy
    - Add proper filtering for completed predictions only
    - Maintain existing ordering and columns

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing view
DROP VIEW IF EXISTS public.leaderboard_with_profiles;

-- Create improved view that includes predictions count from predictions_with_accuracy
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
    FROM public.predictions_with_accuracy pwa
    WHERE pwa.user_id = l.user_id
    AND pwa.real_audience IS NOT NULL
  ), 0) as predictions_count
FROM public.leaderboard l
JOIN public.profiles p ON p.id = l.user_id
ORDER BY 
  l.total_score DESC,
  l.precision_score DESC,
  l.updated_at ASC;

-- Grant access to the view
GRANT SELECT ON public.leaderboard_with_profiles TO authenticated;