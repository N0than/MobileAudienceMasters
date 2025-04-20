/*
  # Fix user prediction count function

  1. Changes
    - Drop existing functions and triggers
    - Recreate rank update functionality
    - Fix user_id type handling in prediction count function

  2. Security
    - Maintain existing security policies
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_leaderboard_ranks ON public.leaderboard;
DROP FUNCTION IF EXISTS public.update_leaderboard_ranks();
DROP FUNCTION IF EXISTS public.get_user_prediction_count(uuid);

-- Function to update ranks
CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS TRIGGER AS $$
BEGIN
  -- Update ranks based on total_score (higher is better)
  WITH ranked_users AS (
    SELECT 
      id,
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
  WHERE l.id = r.id;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update ranks when scores change
CREATE TRIGGER update_leaderboard_ranks
  AFTER INSERT OR UPDATE OF total_score, precision_score
  ON public.leaderboard
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.update_leaderboard_ranks();

-- Function to get prediction count for users with proper type handling
CREATE OR REPLACE FUNCTION public.get_user_prediction_count(user_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.predictions
    WHERE user_id = user_uuid::uuid
  );
END;
$$ LANGUAGE plpgsql;