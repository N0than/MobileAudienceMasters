/*
  # Fix programs table RLS policies

  1. Changes
    - Enable RLS on programs table
    - Add RLS policy for admin users to have full access
    - Add RLS policy for regular users to only read programs

  2. Security
    - Admins can perform all operations (CRUD)
    - Regular users can only read programs
    - Unauthenticated users have no access
*/

-- Enable RLS on programs table
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow read to authenticated users" ON programs;
DROP POLICY IF EXISTS "programs_admin_delete" ON programs;
DROP POLICY IF EXISTS "programs_admin_insert" ON programs;
DROP POLICY IF EXISTS "programs_admin_update" ON programs;
DROP POLICY IF EXISTS "programs_public_select" ON programs;

-- Create new policies

-- Allow admins full access
CREATE POLICY "admins_full_access" ON programs
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
      AND user_roles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
      AND user_roles.role = 'admin'
    )
  );

-- Allow all authenticated users to read programs
CREATE POLICY "authenticated_read_access" ON programs
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);