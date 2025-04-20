/*
  # Add real audience sync functionality

  1. Changes
    - Add function to sync real_audience from programs to predictions
    - Add trigger to automatically update predictions when program real_audience changes
    - Add proper error handling

  2. Security
    - Maintain existing RLS policies
*/

-- Create function to update real_audience in predictions
CREATE OR REPLACE FUNCTION update_real_audience_in_predictions()
RETURNS TRIGGER AS $$
BEGIN
  -- Update real_audience in predictions
  UPDATE public.predictions
  SET 
    real_audience = NEW.real_audience,
    updated_at = NOW()
  WHERE program_id = NEW.id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error in update_real_audience_in_predictions: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to sync real_audience
CREATE TRIGGER on_program_real_audience_update
  AFTER UPDATE OF real_audience
  ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION update_real_audience_in_predictions();

-- Update existing predictions with real_audience values
UPDATE public.predictions p
SET 
  real_audience = pr.real_audience,
  updated_at = NOW()
FROM public.programs pr
WHERE p.program_id = pr.id
AND pr.real_audience IS NOT NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';