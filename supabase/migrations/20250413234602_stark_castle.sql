/*
  # Update badge images

  1. Changes
    - Update icon_url for "Hit Machine" badge
    - Update icon_url for "Graine de Star" badge

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Hit Machine" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/G90gpf2D/Chat-GPT-Image-14-avr-2025-01-10-15-1-min.png'
WHERE name = 'Hit Machine (Argent)';

-- Update the icon_url for the "Graine de Star" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/Kj3sxbZF/Untitled-min.png'
WHERE name = 'Graine de Star (Bronze)';