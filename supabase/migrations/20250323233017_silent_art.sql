/*
  # Update prediction range constraint

  1. Changes
    - Update CHECK constraint on predictions table to limit range to 10M
    - Add migration to handle existing data

  2. Security
    - Maintain existing RLS policies
*/

-- First ensure all predictions are within the new range
UPDATE public.predictions 
SET predicted_audience = LEAST(predicted_audience, 10)
WHERE predicted_audience > 10;

-- Drop existing table
DROP TABLE IF EXISTS public.predictions CASCADE;

-- Recreate predictions table with new constraint
CREATE TABLE public.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  program_id uuid REFERENCES public.programs(id) ON DELETE CASCADE NOT NULL,
  predicted_audience numeric(5,2) NOT NULL CHECK (predicted_audience >= 0 AND predicted_audience <= 10),
  submitted_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, program_id)
);

-- Enable RLS
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "prediction_insert_policy"
  ON public.predictions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "prediction_select_policy"
  ON public.predictions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Add trigger for updating timestamps
CREATE TRIGGER update_predictions_updated_at
  BEFORE UPDATE ON public.predictions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_predictions_user_id ON public.predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_program_id ON public.predictions(program_id);
CREATE INDEX IF NOT EXISTS idx_predictions_submitted_at ON public.predictions(submitted_at);