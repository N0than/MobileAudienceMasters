/*
  # Fix program policies and permissions

  1. Changes
    - Drop existing policies to avoid conflicts
    - Create new policies with proper admin role checks
    - Add policies for both authenticated and public access
    - Fix policy check conditions

  2. Security
    - Maintain RLS enabled
    - Ensure proper admin role validation
*/

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "programs_select_policy" ON public.programs;
DROP POLICY IF EXISTS "programs_insert_policy" ON public.programs;
DROP POLICY IF EXISTS "programs_update_policy" ON public.programs;
DROP POLICY IF EXISTS "programs_delete_policy" ON public.programs;
DROP POLICY IF EXISTS "Anyone can view programs" ON public.programs;
DROP POLICY IF EXISTS "Admin users can insert programs" ON public.programs;
DROP POLICY IF EXISTS "Admin users can update programs" ON public.programs;
DROP POLICY IF EXISTS "Admin users can delete programs" ON public.programs;
DROP POLICY IF EXISTS "Allow read to everyone" ON public.programs;
DROP POLICY IF EXISTS "Allow INSERT for authenticated users" ON public.programs;

-- Enable RLS
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Create policy for program creation by admins
CREATE POLICY "programs_admin_insert"
ON public.programs
FOR INSERT
TO public
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for program updates by admins
CREATE POLICY "programs_admin_update"
ON public.programs
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for program deletion by admins
CREATE POLICY "programs_admin_delete"
ON public.programs
FOR DELETE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for viewing programs (public access)
CREATE POLICY "programs_public_select"
ON public.programs
FOR SELECT
TO public
USING (true);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_programs_created_by ON public.programs(created_by);
CREATE INDEX IF NOT EXISTS idx_programs_updated_at ON public.programs(updated_at);