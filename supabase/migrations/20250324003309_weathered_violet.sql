/*
  # Fix prediction accuracy calculation

  1. Changes
    - Improve accuracy calculation formula
    - Update scoring system
    - Recalculate all existing predictions
    - Update leaderboard rankings

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing trigger first to avoid dependency issues
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;

-- Drop existing functions
DROP FUNCTION IF EXISTS calculate_prediction_accuracy(numeric, numeric);
DROP FUNCTION IF EXISTS calculate_prediction_score(numeric);
DROP FUNCTION IF EXISTS update_predictions_for_program();

-- Improved function to calculate prediction accuracy with better decimal handling
CREATE OR REPLACE FUNCTION calculate_prediction_accuracy(
  predicted numeric,
  actual numeric
) RETURNS numeric AS $$
DECLARE
  diff numeric;
  max_diff numeric := 10; -- Maximum possible difference (scale 0-10)
BEGIN
  -- Handle edge cases
  IF actual IS NULL OR predicted IS NULL THEN
    RETURN 0;
  END IF;

  -- If both are 0, that's 100% accuracy
  IF actual = 0 AND predicted = 0 THEN
    RETURN 100;
  END IF;

  -- If actual is 0 but prediction isn't, calculate based on how far from 0
  IF actual = 0 THEN
    RETURN GREATEST(0, 100 - (predicted / max_diff * 100));
  END IF;

  -- Calculate absolute difference
  diff := ABS(predicted - actual);
  
  -- Calculate accuracy percentage
  -- Use a more gradual scale where difference is relative to the maximum possible difference
  RETURN GREATEST(0, LEAST(100, ROUND((100 - (diff / max_diff * 100))::numeric, 2)));
END;
$$ LANGUAGE plpgsql;

-- Improved function to calculate prediction score with refined tiered system
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
  -- Refined scoring system with more granular tiers:
  RETURN CASE
    WHEN accuracy >= 95 THEN 100  -- Near perfect prediction
    WHEN accuracy >= 90 THEN 90   -- Excellent prediction
    WHEN accuracy >= 85 THEN 80   -- Very good prediction
    WHEN accuracy >= 80 THEN 70   -- Good prediction
    WHEN accuracy >= 75 THEN 60   -- Above average prediction
    WHEN accuracy >= 70 THEN 50   -- Average prediction
    WHEN accuracy >= 65 THEN 40   -- Below average prediction
    WHEN accuracy >= 60 THEN 30   -- Poor prediction
    WHEN accuracy >= 55 THEN 20   -- Very poor prediction
    WHEN accuracy >= 50 THEN 10   -- Extremely poor prediction
    ELSE 0                        -- Inaccurate prediction
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
        ROUND(AVG(accuracy)::numeric, 2) as avg_accuracy
      FROM public.predictions
      WHERE accuracy IS NOT NULL
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

-- Create trigger for updating predictions
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_predictions_for_program();

-- Recalculate all existing predictions with the new formula
DO $$
BEGIN
  -- Update all programs with real audiences to trigger recalculation
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;