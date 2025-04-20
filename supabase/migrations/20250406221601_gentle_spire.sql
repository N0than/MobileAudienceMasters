/*
  # Fix programs table RLS policies

  1. Changes
    - Drop all existing policies to avoid conflicts
    - Create new policies with proper admin role checks
    - Add policies for viewing programs
    - Fix policy naming conflicts

  2. Security
    - Enable RLS
    - Add proper validation for admin role
*/

-- Drop all existing policies to avoid conflicts
DROP POLICY IF EXISTS "admin_insert_programs" ON public.programs;
DROP POLICY IF EXISTS "admin_update_programs" ON public.programs;
DROP POLICY IF EXISTS "admin_delete_programs" ON public.programs;
DROP POLICY IF EXISTS "authenticated_view_programs" ON public.programs;
DROP POLICY IF EXISTS "public_view_programs" ON public.programs;

-- Enable RLS
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Create policy for program creation by admins
CREATE POLICY "admin_insert_programs"
ON public.programs
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for program updates by admins
CREATE POLICY "admin_update_programs"
ON public.programs
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for program deletion by admins
CREATE POLICY "admin_delete_programs"
ON public.programs
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for viewing programs (authenticated users)
CREATE POLICY "authenticated_view_programs"
ON public.programs
FOR SELECT
TO authenticated
USING (true);

-- Create policy for viewing programs (public access)
CREATE POLICY "public_view_programs"
ON public.programs
FOR SELECT
TO public
USING (true);