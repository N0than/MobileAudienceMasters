/*
  # Update RLS policies for programs table

  1. Changes
    - Modify RLS policies to allow authenticated users to view programs
    - Add policy for admin users to manage programs
    - Ensure proper access control based on user roles

  2. Security
    - Maintain RLS enabled on programs table
    - Update policies to be more permissive while maintaining security
*/

-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "Admin users can view all programs" ON programs;
DROP POLICY IF EXISTS "Authenticated users can view all programs" ON programs;
DROP POLICY IF EXISTS "Programs can be created by authenticated users" ON programs;
DROP POLICY IF EXISTS "Programs can be deleted by creators" ON programs;
DROP POLICY IF EXISTS "Programs can be updated by creators" ON programs;

-- Create new policies with proper permissions
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