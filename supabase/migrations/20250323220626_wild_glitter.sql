/*
  # Fix user registration and profile creation

  1. Changes
    - Drop existing triggers and functions
    - Add proper error handling for user creation
    - Fix profile creation flow
    - Add validation for required fields
    - Ensure atomic operations

  2. Security
    - Maintain RLS policies
    - Add proper validation
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Function to handle new user creation with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
  avatar_url_val TEXT;
BEGIN
  -- Get values from metadata with proper validation
  username_val := COALESCE(
    NEW.raw_user_meta_data->>'username',
    SPLIT_PART(NEW.email, '@', 1)
  );
  avatar_url_val := NEW.raw_user_meta_data->>'avatar_url';

  -- Clean and validate username
  username_val := regexp_replace(username_val, '[^a-zA-Z0-9_]', '', 'g');
  IF LENGTH(username_val) < 3 THEN
    username_val := username_val || LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
  END IF;

  -- Ensure unique username
  WHILE EXISTS (
    SELECT 1 FROM public.profiles WHERE username = username_val
  ) LOOP
    username_val := username_val || '_' || FLOOR(RANDOM() * 1000)::TEXT;
  END LOOP;

  BEGIN
    -- Create profile first
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

    -- Update auth metadata
    UPDATE auth.users
    SET raw_user_meta_data = 
      jsonb_build_object(
        'username', username_val,
        'avatar_url', avatar_url_val
      )
    WHERE id = NEW.id;

    RETURN NEW;
  EXCEPTION WHEN OTHERS THEN
    -- Log error details
    RAISE NOTICE 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Update existing users that might be missing profiles
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT u.id, u.email, u.raw_user_meta_data
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE p.id IS NULL
  LOOP
    INSERT INTO public.profiles (
      id,
      username,
      avatar_url,
      created_at,
      updated_at
    ) VALUES (
      user_record.id,
      COALESCE(
        user_record.raw_user_meta_data->>'username',
        SPLIT_PART(user_record.email, '@', 1)
      ) || '_' || FLOOR(RANDOM() * 1000)::TEXT,
      user_record.raw_user_meta_data->>'avatar_url',
      NOW(),
      NOW()
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.leaderboard (
      user_id,
      total_score,
      precision_score,
      rank,
      updated_at
    ) VALUES (
      user_record.id,
      0,
      0,
      COALESCE((SELECT MAX(rank) FROM public.leaderboard), 0) + 1,
      NOW()
    ) ON CONFLICT (user_id) DO NOTHING;
  END LOOP;
END;
$$;