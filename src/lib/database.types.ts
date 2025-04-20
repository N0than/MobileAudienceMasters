type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: number
          username: string
          email: string
          password: string
          created_at: string | null
        }
        Insert: {
          id?: number
          username: string
          email: string
          password: string
          created_at?: string | null
        }
        Update: {
          id?: number
          username?: string
          email?: string
          password?: string
          created_at?: string | null
        }
      }
      profiles: {
        Row: {
          id: string
          username: string
          avatar_url: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          username: string
          avatar_url?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          username?: string
          avatar_url?: string | null
          created_at?: string
          updated_at?: string
        }
      },
      predictions: {
        Row: {
          id: number
          user_id: number | null
          program_id: number | null
          predicted_audience: number
          submitted_at: string | null
        }
        Insert: {
          id?: number
          user_id?: number | null
          program_id?: number | null
          predicted_audience: number
          submitted_at?: string | null
        }
        Update: {
          id?: number
          user_id?: number | null
          program_id?: number | null
          predicted_audience?: number
          submitted_at?: string | null
        }
      },
      programs: {
        Row: {
          id: number
          name: string
          channel: string
          air_date: string
          genre: string | null
          image_url: string | null
          description: string | null
        }
        Insert: {
          id?: number
          name: string
          channel: string
          air_date: string
          genre?: string | null
          image_url?: string | null
          description?: string | null
        }
        Update: {
          id?: number
          name?: string
          channel?: string
          air_date?: string
          genre?: string | null
          image_url?: string | null
          description?: string | null
        }
      },
      actual_audiences: {
        Row: {
          id: number
          program_id: number | null
          real_audience: number
        }
        Insert: {
          id?: number
          program_id?: number | null
          real_audience: number
        }
        Update: {
          id?: number
          program_id?: number | null
          real_audience?: number
        }
      },
      scores: {
        Row: {
          id: number
          user_id: number | null
          program_id: number | null
          score: number
        }
        Insert: {
          id?: number
          user_id?: number | null
          program_id?: number | null
          score: number
        }
        Update: {
          id?: number
          user_id?: number | null
          program_id?: number | null
          score?: number
        }
      },
      leaderboard: {
        Row: {
          id: number
          user_id: number | null
          total_score: number | null
          precision_score: number | null
          rank: number | null
        }
        Insert: {
          id?: number
          user_id?: number | null
          total_score?: number | null
          precision_score?: number | null
          rank?: number | null
        }
        Update: {
          id?: number
          user_id?: number | null
          total_score?: number | null
          precision_score?: number | null
          rank?: number | null
        }
      }
    }
  }
}