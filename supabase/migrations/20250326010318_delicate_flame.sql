/*
  # Add calculated accuracy column

  1. Changes
    - Add calculated_accuracy column to predictions table
    - Update existing predictions with new accuracy calculation
    - Update triggers to maintain calculated accuracy

  2. Security
    - Maintain existing RLS policies
*/

-- Add calculated_accuracy column
ALTER TABLE public.predictions
ADD COLUMN calculated_accuracy numeric(5,2);

-- Update existing predictions with calculated accuracy
UPDATE public.predictions p
SET calculated_accuracy = 
    CASE
        WHEN pr.real_audience IS NULL THEN NULL
        WHEN p.predicted_audience <= pr.real_audience THEN 
            ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
        ELSE 
            ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
    END
FROM public.programs pr
WHERE p.program_id = pr.id;

-- Create or replace the trigger function to include calculated_accuracy
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
      accuracy = calculate_prediction_accuracy(predicted_audience, NEW.real_audience),
      score = calculate_prediction_score(
        calculate_prediction_accuracy(predicted_audience, NEW.real_audience)
      ),
      updated_at = NOW()
    WHERE program_id = NEW.id;

    -- Update leaderboard scores and rankings
    WITH user_scores AS (
      SELECT
        user_id,
        SUM(score) as total_score,
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