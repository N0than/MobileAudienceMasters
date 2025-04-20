/*
  # Add calculated score column and update scoring system

  1. Changes
    - Add calculated_score column to predictions table
    - Update scoring system based on calculated accuracy
    - Update existing predictions with new scores
    - Update trigger function to maintain calculated scores

  2. Security
    - Maintain existing RLS policies
*/

-- Add calculated_score column
ALTER TABLE public.predictions
ADD COLUMN calculated_score integer;

-- Update existing predictions with calculated scores
UPDATE public.predictions
SET calculated_score = 
    CASE
        WHEN calculated_accuracy >= 95 THEN 100   -- 95-100% : 100 points
        WHEN calculated_accuracy >= 90 THEN 80    -- 90-94.99% : 80 points
        WHEN calculated_accuracy >= 85 THEN 60    -- 85-89.99% : 60 points
        WHEN calculated_accuracy >= 80 THEN 50    -- 80-84.99% : 50 points
        WHEN calculated_accuracy >= 70 THEN 30    -- 70-79.99% : 30 points
        WHEN calculated_accuracy >= 60 THEN 20    -- 60-69.99% : 20 points
        WHEN calculated_accuracy >= 50 THEN 10    -- 50-59.99% : 10 points
        ELSE 0                                    -- < 50% : 0 point
    END
WHERE calculated_accuracy IS NOT NULL;

-- Update the trigger function to include calculated_score
CREATE OR REPLACE FUNCTION update_predictions_for_program()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if real_audience is being set or updated
  IF NEW.real_audience IS NOT NULL AND (
    OLD.real_audience IS NULL OR 
    NEW.real_audience != OLD.real_audience
  ) THEN
    -- Round real_audience to one decimal
    NEW.real_audience := ROUND(NEW.real_audience::numeric, 1);

    -- Update all predictions for this program
    UPDATE public.predictions p
    SET
      calculated_accuracy = CASE
        WHEN NEW.real_audience IS NULL THEN NULL
        WHEN predicted_audience <= NEW.real_audience THEN 
          ROUND((predicted_audience / NEW.real_audience) * 100, 2)
        ELSE 
          ROUND((NEW.real_audience / predicted_audience) * 100, 2)
      END,
      calculated_score = CASE
        WHEN calculated_accuracy >= 95 THEN 100
        WHEN calculated_accuracy >= 90 THEN 80
        WHEN calculated_accuracy >= 85 THEN 60
        WHEN calculated_accuracy >= 80 THEN 50
        WHEN calculated_accuracy >= 70 THEN 30
        WHEN calculated_accuracy >= 60 THEN 20
        WHEN calculated_accuracy >= 50 THEN 10
        ELSE 0
      END,
      updated_at = NOW()
    WHERE program_id = NEW.id;

    -- Update leaderboard scores and rankings
    WITH user_scores AS (
      SELECT
        user_id,
        SUM(calculated_score) as total_score,
        ROUND(AVG(calculated_accuracy)::numeric, 1) as avg_accuracy
      FROM public.predictions
      WHERE calculated_accuracy IS NOT NULL
      GROUP BY user_id
    )
    UPDATE public.leaderboard l
    SET
      total_score = COALESCE(us.total_score, 0),
      precision_score = COALESCE(us.avg_accuracy, 0),
      updated_at = NOW()
    FROM user_scores us
    WHERE l.user_id = us.user_id;

    -- Update ranks based on total score and precision
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;