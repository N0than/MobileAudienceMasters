/*
  # Fix RLS policies for programs table

  1. Changes
    - Drop existing RLS policies for programs table
    - Create new RLS policies that properly handle admin access:
      - Allow admins to insert programs
      - Allow admins to update programs
      - Allow authenticated users to view programs
      - Allow public users to view programs
      - Allow admins to delete programs

  2. Security
    - Enable RLS on programs table
    - Add policies for CRUD operations based on user roles
*/

-- Drop existing policies
DROP POLICY IF EXISTS "admin_insert_programs" ON public.programs;
DROP POLICY IF EXISTS "admin_update_programs" ON public.programs;
DROP POLICY IF EXISTS "authenticated_view_programs" ON public.programs;
DROP POLICY IF EXISTS "public_realtime_programs" ON public.programs;
DROP POLICY IF EXISTS "Programs can be deleted by creators" ON public.programs;
DROP POLICY IF EXISTS "admin_delete_programs" ON public.programs;

-- Create new policies
CREATE POLICY "admin_insert_programs" 
ON public.programs
FOR INSERT 
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

CREATE POLICY "admin_update_programs" 
ON public.programs
FOR UPDATE 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

CREATE POLICY "admin_delete_programs" 
ON public.programs
FOR DELETE 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

CREATE POLICY "authenticated_view_programs" 
ON public.programs
FOR SELECT 
TO authenticated
USING (true);

CREATE POLICY "public_view_programs" 
ON public.programs
FOR SELECT 
TO public
USING (true);