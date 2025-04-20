/*
  # Update prediction accuracy calculation

  1. Changes
    - Drop existing triggers and functions with CASCADE
    - Add new accuracy calculation that returns 0 for predictions more than 100% off
    - Update scoring system to be more strict
    - Recalculate all existing predictions

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing triggers and functions with CASCADE to handle dependencies
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs CASCADE;
DROP TRIGGER IF EXISTS on_prediction_update ON public.predictions CASCADE;
DROP FUNCTION IF EXISTS calculate_prediction_accuracy(numeric, numeric) CASCADE;
DROP FUNCTION IF EXISTS calculate_prediction_score(numeric) CASCADE;
DROP FUNCTION IF EXISTS update_predictions_for_program() CASCADE;
DROP FUNCTION IF EXISTS update_user_scores() CASCADE;

-- Function to calculate prediction accuracy with stricter rules
CREATE OR REPLACE FUNCTION calculate_prediction_accuracy(
  predicted numeric,
  actual numeric
) RETURNS numeric AS $$
DECLARE
  percentage_diff numeric;
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

  -- Calculate percentage difference from actual value
  percentage_diff := ABS(predicted - actual) / actual * 100;

  -- Return 0 if prediction is more than 100% off
  IF percentage_diff > 100 THEN
    RETURN 0;
  END IF;

  -- Calculate accuracy score (100 - percentage difference)
  -- Round to 1 decimal place
  RETURN GREATEST(0, ROUND((100 - percentage_diff)::numeric, 1));
END;
$$ LANGUAGE plpgsql;

-- Function to calculate prediction score based on accuracy
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
  -- Scoring system based on accuracy percentage
  RETURN CASE
    WHEN accuracy >= 95 THEN 100  -- Near perfect prediction (within 5%)
    WHEN accuracy >= 90 THEN 90   -- Excellent prediction (within 10%)
    WHEN accuracy >= 85 THEN 80   -- Very good prediction (within 15%)
    WHEN accuracy >= 80 THEN 70   -- Good prediction (within 20%)
    WHEN accuracy >= 75 THEN 60   -- Above average prediction (within 25%)
    WHEN accuracy >= 70 THEN 50   -- Average prediction (within 30%)
    WHEN accuracy >= 65 THEN 40   -- Below average prediction (within 35%)
    WHEN accuracy >= 60 THEN 30   -- Poor prediction (within 40%)
    WHEN accuracy >= 55 THEN 20   -- Very poor prediction (within 45%)
    WHEN accuracy >= 50 THEN 10   -- Extremely poor prediction (within 50%)
    ELSE 0                        -- Inaccurate prediction (more than 50% off)
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to update predictions when real audience changes
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

-- Function to update user scores when predictions change
CREATE OR REPLACE FUNCTION update_user_scores()
RETURNS TRIGGER AS $$
BEGIN
  -- Round predicted_audience to one decimal
  NEW.predicted_audience := ROUND(NEW.predicted_audience::numeric, 1);

  -- Get the program's real audience
  DECLARE
    real_aud numeric;
  BEGIN
    SELECT real_audience INTO real_aud
    FROM public.programs
    WHERE id = NEW.program_id;

    -- If real audience exists, calculate accuracy and score
    IF real_aud IS NOT NULL THEN
      NEW.accuracy := calculate_prediction_accuracy(NEW.predicted_audience, real_aud);
      NEW.score := calculate_prediction_score(NEW.accuracy);
    END IF;
  END;

  -- Update leaderboard for this user
  WITH user_scores AS (
    SELECT
      user_id,
      SUM(score) as total_score,
      ROUND(AVG(accuracy)::numeric, 1) as avg_accuracy
    FROM public.predictions
    WHERE user_id = NEW.user_id
    AND accuracy IS NOT NULL
    GROUP BY user_id
  )
  UPDATE public.leaderboard l
  SET
    total_score = COALESCE(us.total_score, 0),
    precision_score = COALESCE(us.avg_accuracy, 0),
    updated_at = NOW()
  FROM user_scores us
  WHERE l.user_id = us.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_predictions_for_program();

CREATE TRIGGER on_prediction_update
  BEFORE INSERT OR UPDATE ON public.predictions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_scores();

-- Recalculate all existing predictions with new formula
DO $$
BEGIN
  -- Update all programs with real audiences to trigger recalculation
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;