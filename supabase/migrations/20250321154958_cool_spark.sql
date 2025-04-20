/*
  # Sync username with auth display name

  1. Changes
    - Add function to sync username with auth.users display_name
    - Update existing trigger to maintain display_name sync
    - Ensure display_name is updated when username changes

  2. Security
    - Maintain existing RLS policies
    - Keep security checks for username updates
*/

-- Function to sync profile changes with auth metadata and display name
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

-- Update handle_new_user function to set display_name
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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;