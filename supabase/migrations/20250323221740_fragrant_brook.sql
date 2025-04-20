/*
  # Create core tables and fix schema issues

  1. New Tables
    - profiles: Store user profile information
      - id (uuid, references auth.users)
      - username (text, unique)
      - avatar_url (text)
      - created_at (timestamptz)
      - updated_at (timestamptz)
    
    - programs: Store TV program information
      - id (uuid)
      - name (text)
      - channel (text)
      - air_date (timestamptz)
      - genre (text)
      - image_url (text)
      - description (text)
      - created_by (uuid, references auth.users)
      - created_at (timestamptz)
      - updated_at (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add appropriate policies for each table
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
CREATE POLICY "Users can view all profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Create programs table
CREATE TABLE IF NOT EXISTS public.programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  channel text NOT NULL,
  air_date timestamptz NOT NULL,
  genre text,
  image_url text,
  description text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
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

-- Enable RLS on programs
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Create policies for programs
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

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS programs_air_date_idx ON public.programs(air_date);
CREATE INDEX IF NOT EXISTS programs_channel_idx ON public.programs(channel);
CREATE INDEX IF NOT EXISTS programs_genre_idx ON public.programs(genre);
CREATE INDEX IF NOT EXISTS programs_created_by_idx ON public.programs(created_by);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updating timestamps
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_programs_updated_at
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();