/*
  # Update Top Chef badge image

  1. Changes
    - Update icon_url for "Top Chef" badge with new image

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Top Chef" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/G2hK507L/Nouveau-projet-4.png'
WHERE name = 'Top Chef (Or)';