/*
  # Add timestamps to predictions table

  1. Changes
    - Add created_at and updated_at columns to predictions table
    - Add trigger to automatically update updated_at
    - Fix missing columns and constraints

  2. Security
    - Maintain existing RLS policies
*/

-- Add timestamp columns to predictions if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'predictions' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE public.predictions 
    ADD COLUMN created_at timestamptz DEFAULT now(),
    ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating updated_at
DROP TRIGGER IF EXISTS update_predictions_updated_at ON public.predictions;
CREATE TRIGGER update_predictions_updated_at
  BEFORE UPDATE ON public.predictions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update existing rows to have timestamps
UPDATE public.predictions
SET 
  created_at = COALESCE(created_at, now()),
  updated_at = COALESCE(updated_at, now())
WHERE created_at IS NULL OR updated_at IS NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';