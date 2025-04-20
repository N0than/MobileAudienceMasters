import { supabase } from './supabase';
import { PostgrestError } from '@supabase/supabase-js';

export interface Program {
  id: string;
  name: string;
  channel: string;
  air_date: string;
  genre: string;
  image_url?: string;
  description?: string;
  real_audience?: number;
}

// Add a new program
const addProgram = async (programData: Omit<Program, 'id'>) => {
  const { data, error } = await supabase
    .from('programs')
    .insert([programData])
    .select()
    .single();

  if (error) throw error;
  return data.id;
};

// Delete a program
const deleteProgram = async (programId: string) => {
  const { error } = await supabase
    .from('programs')
    .delete()
    .eq('id', programId);

  if (error) throw error;
};

// Update a program
const updateProgram = async (programId: string, programData: Partial<Program>) => {
  const { error } = await supabase
    .from('programs')
    .update(programData)
    .eq('id', programId);

  if (error) throw error;
};

// Get real-time programs updates
const onProgramsUpdate = (callback: (programs: Program[]) => void) => {
  const subscription = supabase
    .channel('programs_changes')
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'programs'
    }, (payload) => {
      // Fetch all programs when changes occur
      getPrograms().then(callback);
    })
    .subscribe();

  // Initial fetch
  getPrograms().then(callback);

  // Return unsubscribe function
  return () => {
    subscription.unsubscribe();
  };
};

// Get all programs
const getPrograms = async () => {
  const { data, error } = await supabase
    .from('programs')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data as Program[];
};

// Predictions
const addPrediction = async (predictionData: {
  user_id: string;
  program_id: string;
  predicted_audience: number;
}) => {
  const { data, error } = await supabase
    .from('predictions')
    .insert([predictionData])
    .select()
    .single();

  if (error) throw error;
  return data;
};

const getUserPredictions = async (userId: string) => {
  const { data, error } = await supabase
    .from('predictions')
    .select('*, programs(*)')
    .eq('user_id', userId);

  if (error) throw error;
  return data;
};

// Actual Audiences
const setActualAudience = async (programId: string, realAudience: number) => {
  const { data, error } = await supabase
    .from('actual_audiences')
    .insert([{
      program_id: programId,
      real_audience: realAudience
    }])
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Scores
const updateUserScore = async (scoreData: {
  user_id: string;
  program_id: string;
  score: number;
}) => {
  const { data, error } = await supabase
    .from('scores')
    .insert([scoreData])
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Leaderboard
const updateLeaderboard = async (userId: string, data: {
  total_score: number;
  precision_score: number;
  rank: number;
}) => {
  const { error: upsertError } = await supabase
    .from('leaderboard')
    .upsert([{
      user_id: userId,
      ...data,
      updated_at: new Date().toISOString()
    }]);

  if (upsertError) throw upsertError;
};