import { createClient } from '@supabase/supabase-js';
import { calculateAccuracy, calculateScore } from './predictions';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

// Create the Supabase client with additional options for better reliability
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'pkce',
    storage: window.localStorage,
    storageKey: 'supabase.auth.token'
  },
  global: {
    headers: {
      'X-Client-Info': 'supabase-js-v2'
    }
  },
  db: {
    schema: 'public'
  },
  realtime: {
    params: {
      eventsPerSecond: 2
    }
  },
  // Add fetch options for better network handling
  fetch: (url, options = {}) => {
    return fetch(url, {
      ...options,
      headers: {
        ...options.headers,
      },
      // Add timeout to prevent hanging requests
      signal: AbortSignal.timeout(30000) // 30 second timeout
    }).catch(error => {
      console.error('Fetch error:', error);
      throw new Error('Network request failed. Please check your connection and try again.');
    });
  }
});

// Test the connection with retry logic and better error handling
const testConnection = async (retries = 3, delay = 1000) => {
  for (let i = 0; i < retries; i++) {
    try {
      const { data, error } = await supabase.from('programs').select('count', { count: 'exact', head: true });
      
      if (error) {
        if (error.code === 'PGRST301') {
          console.warn('Authentication required for this operation');
          continue;
        }
        throw error;
      }
      
      console.log('Supabase connection established successfully');
      return;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error';
      console.warn(`Connection attempt ${i + 1} failed: ${errorMessage}`);
      
      if (i === retries - 1) {
        console.error('Failed to establish Supabase connection after multiple attempts');
        // Don't throw here - let the application continue but log the error
      } else {
        await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, i))); // Exponential backoff
      }
    }
  }
};

// Initialize connection test
testConnection();

// Set up realtime subscription with improved error handling and reconnection
const setupRealtimeSubscription = () => {
  let retryCount = 0;
  const maxRetries = 5;
  
  const connect = () => {
    try {
      const channel = supabase
        .channel('programs_realtime')
        .on(
          'postgres_changes',
          { event: 'UPDATE', schema: 'public', table: 'programs' },
          async (payload) => {
            try {
              console.log('Update detected:', payload);

              const { id, real_audience } = payload.new;

              if (real_audience === undefined || real_audience === null) return;

              const { error } = await supabase
                .from('predictions')
                .update({
                  real_audience: real_audience,
                  calculated_accuracy: calculateAccuracy(real_audience),
                  calculated_score: calculateScore(calculateAccuracy(real_audience)),
                })
                .eq('program_id', id);

              if (error) {
                console.error('Error updating predictions:', error);
                throw error;
              }
            } catch (err) {
              console.error('Error in realtime subscription handler:', err);
            }
          }
        )
        .subscribe((status) => {
          console.log('Realtime subscription status:', status);
          if (status === 'SUBSCRIBED') {
            console.log('Successfully subscribed to realtime changes');
            retryCount = 0; // Reset retry count on successful connection
          } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
            console.log('Realtime subscription closed or errored, attempting to reconnect...');
            if (retryCount < maxRetries) {
              retryCount++;
              const delay = Math.min(1000 * Math.pow(2, retryCount), 30000); // Cap at 30 seconds
              setTimeout(connect, delay);
            } else {
              console.error('Max retry attempts reached for realtime subscription');
            }
          }
        });

      return channel;
    } catch (err) {
      console.error('Failed to set up realtime subscription:', err);
      if (retryCount < maxRetries) {
        retryCount++;
        const delay = Math.min(1000 * Math.pow(2, retryCount), 30000);
        setTimeout(connect, delay);
      }
    }
  };

  connect();
};

// Initialize realtime subscription
setupRealtimeSubscription();