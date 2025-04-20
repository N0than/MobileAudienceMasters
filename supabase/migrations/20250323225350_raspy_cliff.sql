/*
  # Fix predictions table and add submitted_at column

  1. Changes
    - Drop existing predictions table
    - Recreate with proper columns and constraints
    - Add proper indexes and policies
    - Fix user_id handling

  2. Security
    - Enable RLS
    - Add proper policies for predictions
*/

-- Drop existing table
DROP TABLE IF EXISTS public.predictions CASCADE;

-- Create predictions table with proper columns
CREATE TABLE public.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  program_id uuid REFERENCES public.programs(id) ON DELETE CASCADE NOT NULL,
  predicted_audience numeric(5,2) NOT NULL CHECK (predicted_audience >= 0 AND predicted_audience <= 15),
  submitted_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, program_id)
);

-- Enable RLS
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

-- Add RLS policies with unique names
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