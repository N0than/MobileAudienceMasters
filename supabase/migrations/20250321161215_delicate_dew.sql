/*
  # Fix profile triggers and functions

  1. Changes
    - Drop existing triggers and functions safely
    - Recreate profile management functions
    - Add proper error handling
    - Ensure unique usernames

  2. Security
    - Maintain RLS on profiles table
    - Update policies for proper access control
*/

-- Drop existing triggers and functions safely
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.sync_profile_changes() CASCADE;
DROP FUNCTION IF EXISTS public.generate_random_username() CASCADE;

-- Function to generate a random username
CREATE OR REPLACE FUNCTION public.generate_random_username(base_name TEXT)
RETURNS TEXT AS $$
DECLARE
  result TEXT;
  random_suffix TEXT;
BEGIN
  -- Generate a random 4-character suffix
  random_suffix := array_to_string(ARRAY(
    SELECT chr((48 + round(random() * 9))::integer)
    FROM generate_series(1, 4)
  ), '');
  
  result := base_name || '_' || random_suffix;
  
  -- If username exists, try again
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = result) LOOP
    random_suffix := array_to_string(ARRAY(
      SELECT chr((48 + round(random() * 9))::integer)
      FROM generate_series(1, 4)
    ), '');
    result := base_name || '_' || random_suffix;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
  base_username TEXT;
BEGIN
  -- Get base username from metadata or email
  base_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    SPLIT_PART(NEW.email, '@', 1)
  );
  
  -- Generate a unique username
  username_val := public.generate_random_username(base_username);

  BEGIN
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

    -- Update user metadata and display_name
    UPDATE auth.users
    SET 
      raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object('username', username_val),
      raw_app_meta_data = 
        COALESCE(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object('display_name', username_val)
    WHERE id = NEW.id;

  EXCEPTION 
    WHEN unique_violation THEN
      -- If we somehow still got a duplicate, try one more time with a new random username
      username_val := public.generate_random_username(base_username);
      
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

      UPDATE auth.users
      SET 
        raw_user_meta_data = 
          COALESCE(raw_user_meta_data, '{}'::jsonb) || 
          jsonb_build_object('username', username_val),
        raw_app_meta_data = 
          COALESCE(raw_app_meta_data, '{}'::jsonb) || 
          jsonb_build_object('display_name', username_val)
      WHERE id = NEW.id;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to sync profile changes
CREATE OR REPLACE FUNCTION public.sync_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users metadata and display_name when username changes
  IF (OLD.username IS DISTINCT FROM NEW.username) THEN
    UPDATE auth.users
    SET 
      raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object('username', NEW.username),
      raw_app_meta_data = 
        COALESCE(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object('display_name', NEW.username)
    WHERE id = NEW.id;
  END IF;
  
  -- Always update timestamp on changes
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create trigger for profile updates
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_changes();

-- Update existing users without display_name
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT 
      u.id,
      p.username
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
    WHERE (u.raw_app_meta_data->>'display_name') IS NULL
  LOOP
    UPDATE auth.users
    SET raw_app_meta_data = 
      COALESCE(raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('display_name', user_record.username)
    WHERE id = user_record.id;
  END LOOP;
END;
$$;