/*
  # Standardize decimal places to one decimal

  1. Changes
    - Update predictions and programs tables to use numeric(4,1) for audience values
    - Update existing data to round to one decimal
    - Update constraints and validation

  2. Security
    - Maintain existing RLS policies
*/

-- First, round existing values to one decimal
UPDATE public.predictions
SET predicted_audience = ROUND(predicted_audience::numeric, 1)
WHERE predicted_audience IS NOT NULL;

UPDATE public.programs
SET real_audience = ROUND(real_audience::numeric, 1)
WHERE real_audience IS NOT NULL;

-- Modify columns to use numeric(4,1)
ALTER TABLE public.predictions
ALTER COLUMN predicted_audience TYPE numeric(4,1);

ALTER TABLE public.programs
ALTER COLUMN real_audience TYPE numeric(4,1);

-- Update the check constraints
ALTER TABLE public.predictions
DROP CONSTRAINT IF EXISTS predictions_predicted_audience_check,
ADD CONSTRAINT predictions_predicted_audience_check 
  CHECK (predicted_audience >= 0 AND predicted_audience <= 10);

ALTER TABLE public.programs
DROP CONSTRAINT IF EXISTS programs_real_audience_check,
ADD CONSTRAINT programs_real_audience_check 
  CHECK (real_audience >= 0 AND real_audience <= 10);

-- Update the accuracy calculation function to round to one decimal
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

  -- Calculate accuracy as (prediction/actual)*100
  -- Round to 1 decimal place and limit to 0-100 range
  RETURN GREATEST(0, LEAST(100, ROUND((predicted / actual * 100)::numeric, 1)));
END;
$$ LANGUAGE plpgsql;

-- Recalculate all predictions with the new rounding
DO $$
BEGIN
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;