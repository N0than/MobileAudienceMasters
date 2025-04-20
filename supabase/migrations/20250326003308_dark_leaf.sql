/*
  # Add function for recalculating all predictions

  1. Changes
    - Add function to recalculate all predictions and scores
    - Add security checks to ensure only authorized users can trigger recalculation
    - Optimize performance with CTEs and single-query updates

  2. Security
    - Add security definer to allow function to update all predictions
    - Add proper permission checks
*/

-- Create function to recalculate all predictions
CREATE OR REPLACE FUNCTION recalculate_all_predictions(caller_id uuid) 
RETURNS void AS $$
BEGIN
  -- Check if caller has admin role
  IF NOT EXISTS (
    SELECT 1 
    FROM user_roles 
    WHERE user_id = caller_id 
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Permission denied: Only administrators can recalculate predictions';
  END IF;

  -- Recalculate predictions and scores
  WITH updated_predictions AS (
    SELECT 
      p.id, 
      calculate_prediction_accuracy(p.predicted_audience, pr.real_audience) AS new_accuracy
    FROM public.predictions p
    JOIN public.programs pr ON p.program_id = pr.id
    WHERE pr.real_audience IS NOT NULL
  )
  UPDATE public.predictions p
  SET
    accuracy = up.new_accuracy,
    score = calculate_prediction_score(up.new_accuracy),
    updated_at = NOW()
  FROM updated_predictions up
  WHERE p.id = up.id;

  -- Update leaderboard scores and rankings
  WITH user_scores AS (
    SELECT 
      user_id,
      SUM(score) AS total_score,
      ROUND(AVG(accuracy)::numeric, 1) AS avg_accuracy
    FROM public.predictions
    WHERE accuracy IS NOT NULL
    GROUP BY user_id
  ),
  ranked_users AS (
    SELECT 
      user_id,
      total_score,
      avg_accuracy,
      ROW_NUMBER() OVER (
        ORDER BY total_score DESC, 
                avg_accuracy DESC, 
                NOW() ASC
      ) AS new_rank
    FROM user_scores
  )
  UPDATE public.leaderboard l
  SET 
    total_score = r.total_score,
    precision_score = r.avg_accuracy,
    rank = r.new_rank,
    updated_at = NOW()
  FROM ranked_users r
  WHERE l.user_id = r.user_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error in recalculate_all_predictions: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION recalculate_all_predictions(uuid) TO authenticated;

COMMENT ON FUNCTION recalculate_all_predictions(uuid) IS 
'Recalculates all prediction accuracies and scores, and updates the leaderboard. 
Only administrators can execute this function. The caller_id parameter must be the 
UUID of an authenticated user with admin role.';