/*
  # Update prediction accuracy calculation

  1. Changes
    - Add real_audience column to predictions table
    - Update accuracy calculation to handle under/over estimation differently
    - Recalculate all existing predictions
    - Update leaderboard rankings

  2. Security
    - Maintain existing RLS policies
*/

-- Add real_audience column to predictions if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'predictions' AND column_name = 'real_audience'
  ) THEN
    ALTER TABLE public.predictions 
    ADD COLUMN real_audience numeric(4,1);
  END IF;
END $$;

-- Update predictions with real audience values and recalculate accuracy
WITH updated_predictions AS (
  -- Update real_audience from programs table
  UPDATE public.predictions p
  SET real_audience = pr.real_audience
  FROM public.programs pr
  WHERE p.program_id = pr.id
  RETURNING p.id, pr.real_audience, p.predicted_audience
)
UPDATE public.predictions p
SET 
  accuracy = CASE
    WHEN up.real_audience IS NULL THEN NULL
    WHEN up.predicted_audience <= up.real_audience THEN 
      ROUND((up.predicted_audience / up.real_audience) * 100, 2)
    ELSE 
      ROUND((up.real_audience / up.predicted_audience) * 100, 2)
  END,
  score = CASE
    WHEN up.real_audience IS NULL THEN 0
    WHEN up.predicted_audience <= up.real_audience THEN 
      calculate_prediction_score(ROUND((up.predicted_audience / up.real_audience) * 100, 2))
    ELSE 
      calculate_prediction_score(ROUND((up.real_audience / up.predicted_audience) * 100, 2))
  END,
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

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_predictions_real_audience 
ON public.predictions(real_audience);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';