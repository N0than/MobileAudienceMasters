import React, { useEffect, useState } from 'react';
import { RotateCw, Trophy } from 'lucide-react';
import { supabase } from '../lib/supabase';

const UserScore = () => {
  const [score, setScore] = useState<number>(0);
  const [displayScore, setDisplayScore] = useState<number>(0);
  const [isUpdating, setIsUpdating] = useState(false);

  const animateScore = (newScore: number) => {
    const duration = 1000; // 1 seconde pour l'animation
    const frames = 60; // Nombre de frames pour l'animation
    const start = displayScore;
    const difference = newScore - start;
    const increment = difference / frames;
    let frame = 0;

    const animate = () => {
      frame++;
      const current = start + (increment * frame);
      setDisplayScore(Math.round(current));

      if (frame < frames) {
        requestAnimationFrame(animate);
      } else {
        setDisplayScore(newScore);
        setIsUpdating(false);
      }
    };

    requestAnimationFrame(animate);
  };

  const updateScore = async () => {
    try {
      setIsUpdating(true);
      const { data: { user } } = await supabase.auth.getUser(); 
      if (!user) return;

      const { data: predictions } = await supabase
        .from('predictions_with_accuracy')
        .select('calculated_score, real_audience')
        .not('real_audience', 'is', null)
        .eq('user_id', user.id);

      if (predictions) {
        const totalScore = predictions.reduce((sum, pred) => 
          sum + (pred.calculated_score || 0), 0
        );
        setScore(totalScore);
        animateScore(totalScore);
      }
    } catch (error) {
      console.error('Error fetching user score:', error);
      setIsUpdating(false);
    }
  };

  useEffect(() => {
    updateScore();

    // Subscribe to real-time updates
    const channel = supabase.channel('custom-all-channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'predictions',
          filter: `user_id=eq.${supabase.auth.getUser().then(({ data }) => data.user?.id)}`
        },
        () => {
          updateScore();
        }
      )
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, []);

  return (
    <button
      onClick={updateScore}
      disabled={isUpdating}
      className="flex items-center gap-2 relative group"
    >
      <Trophy size={18} className="text-white" />
      <span className="font-semibold text-white flex items-center gap-1">
        {displayScore.toLocaleString()} pts
        {isUpdating && (
          <RotateCw size={14} className="animate-spin ml-1" />
        )}
      </span>
    </button>
  );
};


export default UserScore;