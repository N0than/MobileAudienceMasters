/*
  # Add real audience column and scoring system

  1. Changes
    - Add real_audience column to programs table
    - Add score and accuracy columns to predictions table
    - Add functions for calculating prediction accuracy
    - Add triggers for updating scores

  2. Security
    - Maintain existing RLS policies
*/

-- Add real_audience column to programs if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'programs' AND column_name = 'real_audience'
  ) THEN
    ALTER TABLE public.programs 
    ADD COLUMN real_audience numeric(4,1) CHECK (real_audience >= 0 AND real_audience <= 10);
  END IF;
END $$;

-- Add score and accuracy columns to predictions if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'predictions' AND column_name = 'score'
  ) THEN
    ALTER TABLE public.predictions 
    ADD COLUMN score integer DEFAULT 0,
    ADD COLUMN accuracy numeric(5,2) DEFAULT 0;
  END IF;
END $$;

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

  -- Calculate percentage difference from actual value
  RETURN GREATEST(0, LEAST(100, ROUND((100 - (ABS(predicted - actual) / actual * 100))::numeric, 1)));
END;
$$ LANGUAGE plpgsql;

-- Function to calculate prediction score
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
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

-- Function to update predictions when real audience changes
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating predictions
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_predictions_for_program();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';