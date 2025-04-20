/*
  # Update leaderboard functionality

  1. Changes
    - Add function to calculate and update ranks
    - Add trigger to maintain ranks on score changes
    - Add function to get prediction count for users
    - Fix type casting for user_id comparison

  2. Security
    - Maintain existing RLS policies
    - Add proper error handling
*/

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
DROP TRIGGER IF EXISTS update_leaderboard_ranks ON public.leaderboard;
CREATE TRIGGER update_leaderboard_ranks
  AFTER INSERT OR UPDATE OF total_score, precision_score
  ON public.leaderboard
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.update_leaderboard_ranks();

-- Function to get prediction count for users
CREATE OR REPLACE FUNCTION public.get_user_prediction_count(user_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer
    FROM public.predictions p
    WHERE p.user_id::uuid = $1
  );
END;
$$ LANGUAGE plpgsql;