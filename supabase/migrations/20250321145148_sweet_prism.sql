/*
  # Fix profile table and user management

  1. Changes
    - Create profiles table if not exists
    - Add proper triggers for user management
    - Add function to sync metadata
    - Fix policy conflicts

  2. Security
    - Enable RLS
    - Add proper policies for profile access
*/

-- Drop existing triggers and functions if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.sync_user_metadata();

-- Create profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Create policies
CREATE POLICY "Users can read all profiles"
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

-- Function to handle new user creation with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
  base_username TEXT;
  counter INT := 0;
BEGIN
  -- Get base username from metadata or email
  base_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    SPLIT_PART(NEW.email, '@', 1)
  );
  
  -- Try original username first
  username_val := base_username;
  
  -- Keep trying with incremented counter until we find a unique username
  WHILE EXISTS (
    SELECT 1 FROM public.profiles WHERE username = username_val
  ) LOOP
    counter := counter + 1;
    username_val := base_username || counter::TEXT;
  END LOOP;

  -- Insert into profiles with unique username
  INSERT INTO public.profiles (
    id,
    username,
    avatar_url,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    username_val,
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL),
    NOW(),
    NOW()
  );

  -- Update user metadata with final username
  UPDATE auth.users
  SET raw_user_meta_data = 
    COALESCE(raw_user_meta_data, '{}'::jsonb) || 
    jsonb_build_object('username', username_val)
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to sync profile updates with auth metadata
CREATE OR REPLACE FUNCTION public.sync_user_metadata()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.username IS DISTINCT FROM OLD.username) OR 
     (NEW.avatar_url IS DISTINCT FROM OLD.avatar_url) THEN
    UPDATE auth.users
    SET raw_user_meta_data = 
      COALESCE(raw_user_meta_data, '{}'::jsonb) || 
      jsonb_build_object(
        'username', NEW.username,
        'avatar_url', COALESCE(NEW.avatar_url, null)
      )
    WHERE id = NEW.id;
  END IF;
  
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for profile updates
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_user_metadata();

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles (username);
CREATE INDEX IF NOT EXISTS profiles_created_at_idx ON public.profiles (created_at);
CREATE INDEX IF NOT EXISTS profiles_updated_at_idx ON public.profiles (updated_at);