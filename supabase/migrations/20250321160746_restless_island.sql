/*
  # Fix programs table and add RLS policies

  1. Changes
    - Add missing columns
    - Update constraints
    - Fix RLS policies

  2. Security
    - Enable RLS
    - Add proper policies for program management
*/

-- Drop existing table if it exists
DROP TABLE IF EXISTS public.programs CASCADE;

-- Create programs table
CREATE TABLE public.programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  channel text NOT NULL,
  air_date timestamptz NOT NULL,
  genre text,
  image_url text,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT valid_channel CHECK (
    channel IN (
      'TF1', 'France 2', 'France 3', 'Canal+', 'France 5',
      'M6', 'Arte', 'C8', 'W9', 'TMC'
    )
  ),
  CONSTRAINT valid_genre CHECK (
    genre IN (
      'Divertissement', 'Série', 'Film', 'Information',
      'Sport', 'Documentaire', 'Magazine', 'Jeunesse'
    )
  )
);

-- Enable RLS
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating the updated_at column
CREATE TRIGGER update_programs_updated_at
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Policies
CREATE POLICY "Programs are viewable by everyone"
  ON public.programs
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Programs can be created by authenticated users"
  ON public.programs
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Programs can be updated by creators"
  ON public.programs
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = created_by)
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Programs can be deleted by creators"
  ON public.programs
  FOR DELETE
  TO authenticated
  USING (auth.uid() = created_by);

-- Indexes for better performance
CREATE INDEX programs_air_date_idx ON public.programs (air_date);
CREATE INDEX programs_channel_idx ON public.programs (channel);
CREATE INDEX programs_genre_idx ON public.programs (genre);
CREATE INDEX programs_created_by_idx ON public.programs (created_by);