/*
  # Fix RLS policies for programs table

  1. Changes
    - Update RLS policies for the programs table to allow admin users to view all programs
    - Add policy for admin users to view all programs
    - Add policy for regular users to view all programs (read-only)

  2. Security
    - Maintains RLS enabled on programs table
    - Ensures admin users can perform all operations
    - Allows public read access for all users
*/

-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "Anyone can view programs" ON programs;
DROP POLICY IF EXISTS "Admin users can insert programs" ON programs;
DROP POLICY IF EXISTS "Admin users can update programs" ON programs;
DROP POLICY IF EXISTS "Admin users can delete programs" ON programs;

-- Create new policies
CREATE POLICY "Anyone can view programs"
ON programs FOR SELECT
TO public
USING (true);

CREATE POLICY "Admin users can insert programs"
ON programs FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

CREATE POLICY "Admin users can update programs"
ON programs FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

CREATE POLICY "Admin users can delete programs"
ON programs FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);