/*
  # Update leaderboard view to show all users

  1. Changes
    - Drop existing leaderboard view
    - Create new view that includes all users
    - Add proper ordering for users without predictions
    - Ensure proper null handling

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing view
DROP VIEW IF EXISTS public.leaderboard_with_profiles;

-- Create improved view that includes all users
CREATE VIEW public.leaderboard_with_profiles AS
SELECT 
  COALESCE(l.id, gen_random_uuid()) as id,
  p.id as user_id,
  COALESCE(l.total_score, 0) as total_score,
  COALESCE(l.precision_score, 0) as precision_score,
  COALESCE(l.rank, 
    (SELECT COUNT(*) + 1 FROM public.leaderboard WHERE total_score > 0)
  ) as rank,
  COALESCE(l.updated_at, p.created_at) as updated_at,
  p.username,
  p.avatar_url
FROM public.profiles p
LEFT JOIN public.leaderboard l ON l.user_id = p.id
ORDER BY 
  COALESCE(l.total_score, 0) DESC,
  COALESCE(l.precision_score, 0) DESC,
  p.created_at ASC;

-- Grant access to the view
GRANT SELECT ON public.leaderboard_with_profiles TO authenticated;

-- Update ranks for all users
WITH ranked_users AS (
  SELECT 
    user_id,
    ROW_NUMBER() OVER (
      ORDER BY total_score DESC, 
              precision_score DESC, 
              updated_at ASC
    ) as new_rank
  FROM public.leaderboard
)
UPDATE public.leaderboard l
SET rank = r.new_rank
FROM ranked_users r
WHERE l.user_id = r.user_id;