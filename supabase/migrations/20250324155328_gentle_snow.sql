/*
  # Update prediction accuracy calculation

  1. Changes
    - Update accuracy calculation to use (predicted/actual)*100
    - Keep existing scoring system
    - Recalculate all existing predictions
    - Update leaderboard rankings

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing functions and triggers
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;
DROP FUNCTION IF EXISTS calculate_prediction_accuracy(numeric, numeric);
DROP FUNCTION IF EXISTS calculate_prediction_score(numeric);
DROP FUNCTION IF EXISTS update_predictions_for_program();

-- Function to calculate prediction accuracy
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

  -- Calculate accuracy using formula: (predicted/actual)*100
  -- Round to 1 decimal place and limit to 0-100 range
  RETURN GREATEST(0, LEAST(100, ROUND((predicted / actual * 100)::numeric, 1)));
END;
$$ LANGUAGE plpgsql;

-- Function to calculate prediction score based on accuracy
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
  -- Scoring system based on accuracy percentage
  RETURN CASE
    WHEN accuracy >= 95 THEN 100  -- 95-100%: 100 points
    WHEN accuracy >= 90 THEN 80   -- 90-94.99%: 80 points
    WHEN accuracy >= 85 THEN 60   -- 85-89.99%: 60 points
    WHEN accuracy >= 80 THEN 40   -- 80-84.99%: 40 points
    WHEN accuracy >= 70 THEN 20   -- 70-79.99%: 20 points
    WHEN accuracy >= 50 THEN 10   -- 50-69.99%: 10 points
    ELSE 0                        -- < 50%: 0 points
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to update predictions and leaderboard
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
        ROUND(AVG(accuracy)::numeric, 1) as avg_accuracy
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

-- Recalculate all existing predictions with new formula
DO $$
BEGIN
  -- Update all programs with real audiences to trigger recalculation
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';