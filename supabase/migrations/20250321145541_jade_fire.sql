/*
  # Fix user handling with proper dependency management

  1. Changes
    - Drop existing triggers and functions with CASCADE
    - Recreate user handling function with improved validation
    - Add proper trigger for user creation

  2. Security
    - Maintain RLS on profiles table
    - Add proper validation for user creation
*/

-- Drop existing function with CASCADE to handle dependencies
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Create improved function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
  avatar_url_val TEXT;
BEGIN
  -- Get values from metadata
  username_val := NEW.raw_user_meta_data->>'username';
  avatar_url_val := NEW.raw_user_meta_data->>'avatar_url';

  -- Validate username
  IF username_val IS NULL OR LENGTH(username_val) < 3 THEN
    RAISE EXCEPTION 'Username must be at least 3 characters long';
  END IF;

  -- Check username uniqueness
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = username_val) THEN
    RAISE EXCEPTION 'Username already exists';
  END IF;

  -- Create profile
  INSERT INTO public.profiles (
    id,
    username,
    avatar_url,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    username_val,
    avatar_url_val,
    NOW(),
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;