import { useState } from 'react';

interface FormState {
  title: string;
  channel: string;
  date: string;
  period: string;
  genre: string;
  imageUrl: string;
  description: string;
  real_audience: string;
}

interface UseFormProps {
  initialState: FormState;
  onSubmit: (data: FormState) => Promise<void>;
}

export const useForm = ({ initialState, onSubmit }: UseFormProps) => {
  const [formData, setFormData] = useState<FormState>(initialState);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleChange = (name: keyof FormState, value: string) => {
    setFormData(prev => ({ ...prev, [name]: value }));
    setError(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      // Validation
      if (!formData.title.trim()) {
        throw new Error('Le titre est requis');
      }
      if (!formData.channel) {
        throw new Error('La chaîne est requise');
      }
      if (!formData.date) {
        throw new Error('La date est requise');
      }
      if (!formData.period) {
        throw new Error('La période de diffusion est requise');
      }

      // Real audience validation if provided
      if (formData.real_audience) {
        const audience = parseFloat(formData.real_audience);
        if (isNaN(audience) || audience < 0 || audience > 10) {
          throw new Error("L'audience réelle doit être comprise entre 0 et 10 millions");
        }
      }

      await onSubmit(formData);
      setFormData(initialState);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setFormData(initialState);
    setError(null);
  };

  return {
    formData,
    error,
    loading,
    handleChange,
    handleSubmit,
    resetForm
  };
};