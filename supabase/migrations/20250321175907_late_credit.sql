/*
  # Fix user registration and profile creation

  1. Changes
    - Drop existing triggers and functions to avoid conflicts
    - Improve error handling in handle_new_user function
    - Add better validation for username
    - Ensure proper profile creation
    - Fix metadata synchronization

  2. Security
    - Maintain RLS policies
    - Ensure secure profile creation
*/

-- Drop existing triggers and functions safely
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.sync_profile_changes() CASCADE;

-- Function to handle new user creation with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
  base_username TEXT;
  counter INT := 0;
BEGIN
  -- Get username from metadata or generate from email
  base_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    SPLIT_PART(NEW.email, '@', 1)
  );

  -- Ensure minimum length
  IF LENGTH(base_username) < 3 THEN
    base_username := base_username || LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
  END IF;

  -- Try original username first
  username_val := base_username;
  
  -- Keep trying with incremented counter until we find a unique username
  WHILE EXISTS (
    SELECT 1 FROM public.profiles WHERE username = username_val
  ) LOOP
    counter := counter + 1;
    username_val := base_username || counter::TEXT;
  END LOOP;

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

    -- Update user metadata
    UPDATE auth.users
    SET raw_user_meta_data = 
      COALESCE(raw_user_meta_data, '{}'::jsonb) || 
      jsonb_build_object(
        'username', username_val,
        'avatar_url', COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
      )
    WHERE id = NEW.id;

  EXCEPTION 
    WHEN unique_violation THEN
      -- If we somehow still got a duplicate, try one more time with timestamp
      username_val := base_username || '_' || EXTRACT(EPOCH FROM NOW())::TEXT;
      
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
      SET raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object(
          'username', username_val,
          'avatar_url', COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
        )
      WHERE id = NEW.id;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to sync profile changes
CREATE OR REPLACE FUNCTION public.sync_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users metadata when profile changes
  IF (OLD.username IS DISTINCT FROM NEW.username) OR 
     (OLD.avatar_url IS DISTINCT FROM NEW.avatar_url) THEN
    UPDATE auth.users
    SET raw_user_meta_data = 
      COALESCE(raw_user_meta_data, '{}'::jsonb) || 
      jsonb_build_object(
        'username', NEW.username,
        'avatar_url', COALESCE(NEW.avatar_url, NULL)
      )
    WHERE id = NEW.id;
  END IF;
  
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_changes();