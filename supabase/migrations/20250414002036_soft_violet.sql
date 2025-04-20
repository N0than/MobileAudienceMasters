/*
  # Update badge images with new designs

  1. Changes
    - Update icon_url for "Objectif Top Chef" badge
    - Update icon_url for "Un diner presque parfait" badge
    - Update icon_url for "Destination X" badge
    - Update icon_url for "Top Chef" badge

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Objectif Top Chef" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/x1jH9jR2/Chat-GPT-Image-14-avr-2025-02-04-11-1.png'
WHERE name = 'Objectif Top Chef';

-- Update the icon_url for "Un diner presque parfait" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/nLFtdgpT/Nouveau-projet-2.png'
WHERE name = 'Un diner presque parfait';

-- Update the icon_url for the "Destination X" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/3N54Vm9K/Chat-GPT-Image-14-avr-2025-02-16-01-1.png'
WHERE name = 'Destination X';

-- Update the icon_url for the "Top Chef" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/MTRNzJ0y/Nouveau-projet-3.png'
WHERE name = 'Top Chef (Or)';