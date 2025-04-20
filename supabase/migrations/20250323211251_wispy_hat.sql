/*
  # Fix user creation and profile handling

  1. Changes
    - Drop existing triggers and functions
    - Add improved validation for usernames
    - Fix profile creation
    - Add proper error handling
    - Ensure atomic operations

  2. Security
    - Maintain RLS policies
    - Add proper validation
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Function to handle new user creation with better validation
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

  -- Check username format
  IF NOT username_val ~ '^[a-zA-Z0-9_]+$' THEN
    RAISE EXCEPTION 'Username can only contain letters, numbers, and underscores';
  END IF;

  -- Check username uniqueness
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = username_val) THEN
    RAISE EXCEPTION 'Username already exists';
  END IF;

  BEGIN
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

    -- Create initial leaderboard entry
    INSERT INTO public.leaderboard (
      user_id,
      total_score,
      precision_score,
      rank,
      updated_at
    ) VALUES (
      NEW.id,
      0,
      0,
      COALESCE((SELECT MAX(rank) FROM public.leaderboard), 0) + 1,
      NOW()
    );

  EXCEPTION 
    WHEN unique_violation THEN
      -- If we get a unique violation, try with a modified username
      INSERT INTO public.profiles (
        id,
        username,
        avatar_url,
        created_at,
        updated_at
      ) VALUES (
        NEW.id,
        username_val || '_' || floor(random() * 1000)::text,
        avatar_url_val,
        NOW(),
        NOW()
      );

      INSERT INTO public.leaderboard (
        user_id,
        total_score,
        precision_score,
        rank,
        updated_at
      ) VALUES (
        NEW.id,
        0,
        0,
        COALESCE((SELECT MAX(rank) FROM public.leaderboard), 0) + 1,
        NOW()
      );
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();