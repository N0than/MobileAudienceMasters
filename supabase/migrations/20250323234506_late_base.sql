/*
  # Create leaderboard view with profiles

  1. Changes
    - Create a view that joins leaderboard with profiles
    - Grant proper access permissions
    - No foreign key changes needed since it already exists

  2. Security
    - Maintain existing RLS policies
    - Grant access to authenticated users
*/

-- Create or replace the view for leaderboard with profiles
CREATE OR REPLACE VIEW public.leaderboard_with_profiles AS
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