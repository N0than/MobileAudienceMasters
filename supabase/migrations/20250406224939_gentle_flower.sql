/*
  # Fix RLS policies for programs table

  1. Changes
    - Drop existing SELECT policy that only allows public access
    - Add new SELECT policy that allows admin users to view all programs
    - Add new SELECT policy that allows authenticated users to view all programs
    
  2. Security
    - Enable RLS on programs table (already enabled)
    - Add policies for admin and authenticated users
*/

-- Drop the existing "Anyone can view shows" policy
DROP POLICY IF EXISTS "Anyone can view shows" ON public.programs;

-- Add new SELECT policy for admin users
CREATE POLICY "Admin users can view all programs"
ON public.programs
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1
    FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Add new SELECT policy for authenticated users
CREATE POLICY "Authenticated users can view all programs"
ON public.programs
FOR SELECT
TO authenticated
USING (true);