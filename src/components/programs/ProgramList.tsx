import React, { useEffect, useState } from 'react';
import { RotateCw, RefreshCcw, Filter } from 'lucide-react';
import { Program } from '../../lib/database';
import { supabase } from '../../lib/supabase';
import ProgramCard from './ProgramCard';

const ProgramList = () => {
  const [programs, setPrograms] = useState<Program[]>([]);
  const [showOnlyAvailable, setShowOnlyAvailable] = useState(true);
  const [username, setUsername] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [userPredictions, setUserPredictions] = useState<Set<string>>(new Set());

  const fetchPrograms = async () => {
    try {
      setLoading(true);
      setIsRefreshing(true);
      setError(null);

      const { data, error } = await supabase
        .from('programs')
        .select('*')
        .gte('air_date', new Date().toISOString())
        .order('air_date', { ascending: true });

      if (error) {
        throw new Error(`Failed to fetch programs: ${error.message}`);
      }
      
      setPrograms(data || []);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch programs';
      console.error('Error fetching programs:', err);
      setError(errorMessage);
    } finally {
      setLoading(false);
      setTimeout(() => setIsRefreshing(false), 500);
    }
  };

  const fetchUserPredictions = async () => {
    try {
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      
      if (userError) {
        throw new Error(`Authentication error: ${userError.message}`);
      }
      
      if (!user) return;

      const { data: predictions, error: predictionsError } = await supabase
        .from('predictions')
        .select('program_id')
        .eq('user_id', user.id);

      if (predictionsError) {
        throw new Error(`Failed to fetch predictions: ${predictionsError.message}`);
      }

      if (predictions) {
        setUserPredictions(new Set(predictions.map(p => p.program_id)));
      }
    } catch (error) {
      console.error('Error fetching user predictions:', error);
    }
  };

  useEffect(() => {
    const fetchUsername = async () => {
      try {
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        
        if (userError) {
          throw new Error(`Authentication error: ${userError.message}`);
        }
        
        if (user) {
          const { data, error: profileError } = await supabase
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .single();

          if (profileError) {
            throw new Error(`Failed to fetch profile: ${profileError.message}`);
          }

          if (data) {
            setUsername(data.username);
          }
        }
      } catch (error) {
        console.error('Error fetching username:', error);
      }
    };

    fetchUsername();
    fetchPrograms();
    fetchUserPredictions();

    // Subscribe to changes with error handling
    const channel = supabase
      .channel('programs_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'programs'
      }, () => {
        fetchPrograms();
      })
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('Successfully subscribed to program changes');
        } else if (status === 'CHANNEL_ERROR') {
          console.error('Error in program changes subscription');
        }
      });

    return () => {
      channel.unsubscribe();
    };
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center items-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-500">{error}</p>
        <button
          onClick={fetchPrograms}
          className="mt-4 flex items-center gap-2 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors mx-auto"
        >
          <RotateCw size={16} />
          <span>Réessayer</span>
        </button>
      </div>
    );
  }

  if (programs.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500 dark:text-gray-400">
        Aucun programme à venir disponible pour le moment
      </div>
    );
  }

  const filteredPrograms = showOnlyAvailable 
    ? programs.filter(program => !userPredictions.has(program.id))
    : programs;

  const showUpToDateMessage = showOnlyAvailable && filteredPrograms.length === 0 && programs.length > 0;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:justify-between gap-4 sm:items-center">
        <div className="w-full sm:w-auto">
          <button
            onClick={fetchPrograms}
            className="button relative flex items-center overflow-hidden rounded-full bg-gray-800/90 backdrop-blur-md w-full"
            style={{ '--clr': '#6f5e90' } as React.CSSProperties}
          >
            <div className="button-decor"></div>
            <div className="button-content">
              <span className="button__icon">
                <RefreshCcw size={18} className={`text-white transition-transform ${isRefreshing ? 'animate-spin' : ''}`} />
              </span>
              <span className="button__text">
                Actualiser
              </span>
            </div>
          </button>
        </div>
        <div className="w-full sm:w-auto">
          <button
            onClick={() => setShowOnlyAvailable(!showOnlyAvailable)}
            className="button relative flex items-center overflow-hidden rounded-full bg-gray-800/90 backdrop-blur-md w-full"
            style={{ '--clr': showOnlyAvailable ? '#6f5e90' : '#6f5e90' } as React.CSSProperties}
          >
            <div className="button-decor"></div>
            <div className="button-content">
              <span className="button__icon">
                <Filter size={18} className="text-white" />
              </span>
              <span className="button__text">
                {showOnlyAvailable ? 'Tous les pronostics' : 'Pronostics en attente'}
              </span>
            </div>
          </button>
        </div>
      </div>

      {showUpToDateMessage ? (
        <div className="text-center py-12">
          <img
            src="https://i.postimg.cc/nrWKYG3c/Chat-GPT-Image-10-avr-2025-01-52-01.png"
            alt="TV Icon"
            className="w-80 h-80 mx-auto mb-6"
          />
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-green-100 dark:bg-green-900/20 text-green-600 dark:text-green-400">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            <span className="font-medium">Vos pronostics sont à jour</span>
          </div>
        </div>
      ) : (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredPrograms.map((program) => (
          <ProgramCard 
            key={program.id} 
            program={program}
            onPredictionSubmit={fetchPrograms}
          />
        ))}
      </div>
      )}
    </div>
  );
};

export default ProgramList;