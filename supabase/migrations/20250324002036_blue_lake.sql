/*
  # Fix prediction accuracy calculation and scoring system

  1. Changes
    - Drop existing trigger first
    - Improve accuracy calculation logic
    - Add tiered scoring system
    - Add triggers for automatic updates

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing trigger first to avoid dependency issues
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;

-- Drop existing functions
DROP FUNCTION IF EXISTS calculate_prediction_accuracy(numeric, numeric);
DROP FUNCTION IF EXISTS calculate_prediction_score(numeric);
DROP FUNCTION IF EXISTS update_predictions_for_program();

-- Improved function to calculate prediction accuracy
CREATE OR REPLACE FUNCTION calculate_prediction_accuracy(
  predicted numeric,
  actual numeric
) RETURNS numeric AS $$
BEGIN
  -- Handle edge cases
  IF actual IS NULL OR predicted IS NULL THEN
    RETURN 0;
  END IF;

  -- If both are 0, that's 100% accuracy
  IF actual = 0 AND predicted = 0 THEN
    RETURN 100;
  END IF;

  -- If actual is 0 but prediction isn't, that's 0% accuracy
  IF actual = 0 THEN
    RETURN 0;
  END IF;

  -- Calculate percentage difference and round to 2 decimal places
  -- The closer the prediction is to the actual value, the higher the accuracy
  -- Maximum accuracy is 100%, minimum is 0%
  RETURN GREATEST(0, LEAST(100, ROUND((100 - (ABS(predicted - actual) / actual * 100))::numeric, 2)));
END;
$$ LANGUAGE plpgsql;

-- Improved function to calculate prediction score with tiered system
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
  -- Tiered scoring system:
  -- 90-100% accuracy = 100 points (Perfect prediction)
  -- 80-89% accuracy = 80 points (Excellent prediction)
  -- 70-79% accuracy = 60 points (Good prediction)
  -- 60-69% accuracy = 40 points (Fair prediction)
  -- 50-59% accuracy = 20 points (Poor prediction)
  -- Below 50% = 0 points (Inaccurate prediction)
  RETURN CASE
    WHEN accuracy >= 90 THEN 100
    WHEN accuracy >= 80 THEN 80
    WHEN accuracy >= 70 THEN 60
    WHEN accuracy >= 60 THEN 40
    WHEN accuracy >= 50 THEN 20
    ELSE 0
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to update predictions and leaderboard when real audience is set
CREATE OR REPLACE FUNCTION update_predictions_for_program()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if real_audience is being set or updated
  IF NEW.real_audience IS NOT NULL AND (
    OLD.real_audience IS NULL OR 
    NEW.real_audience != OLD.real_audience
  ) THEN
    -- Update all predictions for this program
    UPDATE public.predictions
    SET
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
        AVG(accuracy) as avg_accuracy
      FROM public.predictions
      WHERE accuracy IS NOT NULL
      GROUP BY user_id
    )
    UPDATE public.leaderboard l
    SET
      total_score = COALESCE(us.total_score, 0),
      precision_score = ROUND(COALESCE(us.avg_accuracy, 0)::numeric, 2),
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

-- Create trigger for updating predictions
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_predictions_for_program();

-- Update existing predictions to recalculate scores with new system
DO $$
BEGIN
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;