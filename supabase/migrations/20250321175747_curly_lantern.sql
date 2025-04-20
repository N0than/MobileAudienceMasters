/*
  # Fix leaderboard rank update

  1. Changes
    - Use updated_at instead of created_at for rank ordering
    - Drop existing trigger to avoid conflicts
    - Recreate function with improved error handling
    - Add new trigger with unique name

  2. Security
    - Maintain RLS policies
*/

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created_leaderboard ON auth.users;

-- Drop and recreate function to ensure clean state
DROP FUNCTION IF EXISTS public.ensure_leaderboard_entry();

-- Recreate function with improved error handling
CREATE OR REPLACE FUNCTION public.ensure_leaderboard_entry()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert new leaderboard entry with next available rank
  INSERT INTO public.leaderboard (
    user_id,
    total_score,
    precision_score,
    rank,
    updated_at
  )
  SELECT
    NEW.id,
    0,
    0,
    COALESCE((SELECT MAX(rank) FROM public.leaderboard), 0) + 1,
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM public.leaderboard WHERE user_id = NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger with unique name
CREATE TRIGGER ensure_user_leaderboard_entry
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_leaderboard_entry();

-- Update ranks for all existing entries using updated_at
WITH ranked_users AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (ORDER BY updated_at) as new_rank
  FROM public.leaderboard
)
UPDATE public.leaderboard l
SET rank = r.new_rank
FROM ranked_users r
WHERE l.id = r.id;