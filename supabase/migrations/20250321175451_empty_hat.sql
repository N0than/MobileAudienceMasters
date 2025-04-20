/*
  # Add leaderboard trigger for new users

  1. Changes
    - Add trigger function to create leaderboard entry for new users
    - Add trigger to automatically create leaderboard entry on user creation
    - Add initial leaderboard entries for existing users

  2. Security
    - Maintain existing RLS policies
*/

-- Function to create leaderboard entry
CREATE OR REPLACE FUNCTION public.ensure_leaderboard_entry()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.leaderboard (
    user_id,
    total_score,
    precision_score,
    rank,
    updated_at
  ) VALUES (
    NEW.id,
    0,
    0,
    (SELECT COALESCE(MAX(rank), 0) + 1 FROM public.leaderboard),
    NOW()
  ) ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created_leaderboard
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_leaderboard_entry();

-- Create leaderboard entries for existing users
INSERT INTO public.leaderboard (
  user_id,
  total_score,
  precision_score,
  rank,
  updated_at
)
SELECT 
  u.id,
  0,
  0,
  ROW_NUMBER() OVER (ORDER BY u.created_at),
  NOW()
FROM auth.users u
LEFT JOIN public.leaderboard l ON l.user_id = u.id
WHERE l.id IS NULL
ON CONFLICT (user_id) DO NOTHING;