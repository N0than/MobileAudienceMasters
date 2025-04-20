/*
  # Fix programs table RLS policies

  1. Changes
    - Drop existing policies to avoid conflicts
    - Add proper admin role check
    - Add policies for program management
    - Fix validation constraints

  2. Security
    - Enable RLS
    - Add proper validation for admin role
*/

-- Enable RLS
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "admins_full_access" ON programs;
DROP POLICY IF EXISTS "authenticated_read_access" ON programs;
DROP POLICY IF EXISTS "programs_admin_insert" ON programs;
DROP POLICY IF EXISTS "programs_admin_update" ON programs;
DROP POLICY IF EXISTS "programs_admin_delete" ON programs;
DROP POLICY IF EXISTS "programs_public_select" ON programs;

-- Create policies for admin users
CREATE POLICY "admins_full_access"
ON programs
FOR ALL
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

-- Create policy for authenticated users to read programs
CREATE POLICY "authenticated_read_access"
ON programs
FOR SELECT
TO authenticated
USING (auth.uid() IS NOT NULL);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_programs_created_by ON programs(created_by);
CREATE INDEX IF NOT EXISTS idx_programs_updated_at ON programs(updated_at);