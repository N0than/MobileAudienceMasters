/*
  # Add real audience and scoring functionality

  1. Changes
    - Add real_audience column to programs table
    - Add score and accuracy columns to predictions table
    - Add functions to calculate scores and update leaderboard
    - Add triggers to handle real audience updates

  2. Security
    - Maintain existing RLS policies
    - Add proper validation for real audience values
*/

-- Add real_audience column to programs table
ALTER TABLE public.programs
ADD COLUMN real_audience numeric(5,2) CHECK (real_audience >= 0 AND real_audience <= 10);

-- Add score and accuracy columns to predictions table
ALTER TABLE public.predictions
ADD COLUMN score integer DEFAULT 0,
ADD COLUMN accuracy numeric(5,2) DEFAULT 0;

-- Function to calculate prediction accuracy
CREATE OR REPLACE FUNCTION calculate_prediction_accuracy(
  predicted numeric,
  actual numeric
) RETURNS numeric AS $$
BEGIN
  -- If actual is 0, avoid division by zero
  IF actual = 0 THEN
    RETURN CASE
      WHEN predicted = 0 THEN 100
      ELSE 0
    END;
  END IF;

  -- Calculate accuracy percentage
  RETURN GREATEST(0, 100 - (ABS(predicted - actual) / actual * 100));
END;
$$ LANGUAGE plpgsql;

-- Function to calculate prediction score
CREATE OR REPLACE FUNCTION calculate_prediction_score(
  accuracy numeric
) RETURNS integer AS $$
BEGIN
  -- Convert accuracy percentage to points (max 100 points)
  RETURN GREATEST(0, ROUND(accuracy)::integer);
END;
$$ LANGUAGE plpgsql;

-- Function to update predictions when real audience is set
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

    -- Update leaderboard scores
    WITH user_scores AS (
      SELECT
        user_id,
        SUM(score) as total_score,
        AVG(accuracy) as avg_accuracy
      FROM public.predictions
      GROUP BY user_id
    )
    UPDATE public.leaderboard l
    SET
      total_score = COALESCE(us.total_score, 0),
      precision_score = ROUND(COALESCE(us.avg_accuracy, 0)::numeric, 2),
      updated_at = NOW()
    FROM user_scores us
    WHERE l.user_id = us.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating predictions when real audience is set
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_predictions_for_program();

-- Update existing predictions if there are any programs with real_audience
DO $$
BEGIN
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;