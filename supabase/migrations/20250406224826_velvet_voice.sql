/*
  # Fix admin policies for program management

  1. Changes
    - Drop existing policies to avoid conflicts
    - Create new policies with proper admin role checks
    - Add proper validation for program updates
    - Enable RLS with correct permissions

  2. Security
    - Maintain RLS enabled
    - Ensure proper admin role validation
*/

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "admin_insert_programs" ON public.programs;
DROP POLICY IF EXISTS "admin_update_programs" ON public.programs;
DROP POLICY IF EXISTS "admin_delete_programs" ON public.programs;
DROP POLICY IF EXISTS "public_view_programs" ON public.programs;

-- Enable RLS
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Create policy for program creation by admins
CREATE POLICY "Programs can be created by authenticated users"
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
CREATE POLICY "Programs can be updated by creators"
ON public.programs
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

-- Create policy for program deletion by admins
CREATE POLICY "Programs can be deleted by creators"
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

-- Create policy for viewing programs
CREATE POLICY "Anyone can view shows"
ON public.programs
FOR SELECT
TO public
USING (true);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_programs_created_by ON public.programs(created_by);
CREATE INDEX IF NOT EXISTS idx_programs_updated_at ON public.programs(updated_at);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';