/*
  # Create predictions table and related functions

  1. New Tables
    - predictions: Store user predictions for program audiences
      - id (uuid, primary key)
      - user_id (uuid, references auth.users)
      - program_id (uuid, references programs)
      - predicted_audience (numeric(5,2))
      - submitted_at (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for authenticated users
    - Add validation triggers
*/

-- Drop existing triggers and functions if they exist
DROP TRIGGER IF EXISTS before_prediction_insert ON public.predictions;
DROP FUNCTION IF EXISTS public.validate_prediction();

-- Create predictions table
CREATE TABLE IF NOT EXISTS public.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  program_id uuid REFERENCES public.programs(id) ON DELETE CASCADE NOT NULL,
  predicted_audience numeric(5,2) NOT NULL CHECK (predicted_audience >= 0 AND predicted_audience <= 15),
  submitted_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(user_id, program_id)
);

-- Enable RLS
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert their own predictions" ON public.predictions;
DROP POLICY IF EXISTS "Users can view their own predictions" ON public.predictions;

-- Add validation trigger function
CREATE OR REPLACE FUNCTION public.validate_prediction()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if program exists
  IF NOT EXISTS (SELECT 1 FROM public.programs WHERE id = NEW.program_id) THEN
    RAISE EXCEPTION 'Program does not exist';
  END IF;

  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
    RAISE EXCEPTION 'User does not exist';
  END IF;

  -- Validate prediction value
  IF NEW.predicted_audience < 0 OR NEW.predicted_audience > 15 THEN
    RAISE EXCEPTION 'Predicted audience must be between 0 and 15';
  END IF;

  -- Set submitted_at if not provided
  IF NEW.submitted_at IS NULL THEN
    NEW.submitted_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create validation trigger
CREATE TRIGGER before_prediction_insert
  BEFORE INSERT ON public.predictions
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_prediction();

-- Add RLS policies
CREATE POLICY "Users can insert their own predictions"
  ON public.predictions
  FOR INSERT
  TO authenticated
  WITH CHECK ((auth.uid())::text = (user_id)::text);

CREATE POLICY "Users can view their own predictions"
  ON public.predictions
  FOR SELECT
  TO authenticated
  USING ((auth.uid())::text = (user_id)::text);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_predictions_user_id ON public.predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_program_id ON public.predictions(program_id);
CREATE INDEX IF NOT EXISTS idx_predictions_submitted_at ON public.predictions(submitted_at);