import React, { useState, useEffect, useCallback } from 'react';
import { BarChart2, Bell, RotateCw, PenLine, Trash2, Plus } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useForm } from '../../hooks/useForm';
import ConfirmationDialog from '../common/ConfirmationDialog';

interface Program {
  id: number;
  name: string;
  channel: string;
  air_date: string;
  genre: string | null;
  image_url: string | null;
  description: string | null;
  broadcast_period?: string;
  real_audience?: number;
}

const StatCard = ({ icon, title, value }: { icon: React.ReactNode; title: string; value: string | number }) => (
  <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm">
    <div className="flex items-center gap-3 mb-4">
      <div className="text-purple-500">{icon}</div>
      <h3 className="text-gray-900 dark:text-white font-medium">{title}</h3>
    </div>
    <p className="text-2xl font-bold text-gray-900 dark:text-white">{value}</p>
  </div>
);

const AdminPage = () => {
  const [showAddForm, setShowAddForm] = useState(false);
  const [programs, setPrograms] = useState<Program[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [editingProgramId, setEditingProgramId] = useState<string | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [programToDelete, setProgramToDelete] = useState<Program | null>(null);
  
  const initialFormState = {
    title: '',
    channel: '',
    date: '',
    period: 'Prime-time',
    genre: '',
    imageUrl: '',
    real_audience: '',
    description: ''
  };

  const { formData, error, loading, handleChange, handleSubmit, resetForm } = useForm({
    initialState: initialFormState,
    onSubmit: async (data) => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Utilisateur non connecté');

      const programData = {
        name: data.title,
        channel: data.channel,
        air_date: data.date ? new Date(data.date + 'T00:00:00').toISOString() : null,
        broadcast_period: data.period,
        genre: data.genre || null,
        image_url: data.imageUrl || null,
        description: data.description || null,
        real_audience: data.real_audience ? parseFloat(data.real_audience) : null
      };

      if (editingProgramId) {
        const { error } = await supabase
          .from('programs')
          .update(programData)
          .eq('id', editingProgramId);
        
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('programs')
          .insert([{
            ...programData,
            created_by: user.id
          }]);
        
        if (error) throw error;
      }

      await fetchPrograms();
      setShowAddForm(false);
      setEditingProgramId(null);
    }
  });

  const fetchPrograms = async () => {
    try {
      setIsRefreshing(true);
      const { data, error } = await supabase
        .from('programs')
        .select(`
          id,
          name,
          channel,
          air_date,
          genre,
          image_url,
          description,
          broadcast_period,
          real_audience,
          created_by,
          created_at,
          updated_at
        `)
        .order('air_date', { ascending: false });

      if (error) throw error;
      setPrograms(data || []);
    } catch (error) {
      console.error('Error fetching programs:', error);
    } finally {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchPrograms();

    // Set up real-time subscription
    const channel = supabase.channel('custom-all-channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'programs'
        },
        () => {
          fetchPrograms();
        }
      )
      .subscribe();

    return () => { channel.unsubscribe(); };
  }, []);

  const handleShowForm = () => {
    resetForm();
    setShowAddForm(!showAddForm);
    setEditingProgramId(null);
  };

  const handleEdit = (program: Program) => {
    handleChange('title', program.name);
    handleChange('channel', program.channel);
    handleChange('date', program.air_date ? new Date(program.air_date).toLocaleDateString('fr-CA') : '');
    handleChange('period', program.broadcast_period || 'Prime-time');
    handleChange('genre', program.genre || '');
    handleChange('imageUrl', program.image_url || '');
    handleChange('real_audience', program.real_audience ? program.real_audience.toString() : '');
    handleChange('description', program.description || '');
    setEditingProgramId(program.id);
    setShowAddForm(true);
  };

  const handleDeleteClick = (program: Program) => {
    setProgramToDelete(program);
    setShowDeleteConfirm(true);
  };

  const handleDeleteConfirm = async () => {
    if (!programToDelete) return;

    try {
      const { error } = await supabase
        .from('programs')
        .delete()
        .eq('id', programToDelete.id);
      
      if (error) throw error;
      
      await fetchPrograms();
      setShowDeleteConfirm(false);
      setProgramToDelete(null);
    } catch (error) {
      console.error('Error deleting program:', error);
    }
  };

  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
        Administration
      </h1>

      <div className="grid grid-cols-2 gap-6">
        <StatCard
          icon={<BarChart2 size={24} />}
          title="Total Programmes"
          value={programs.length}
        />
        <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm col-span-1">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex items-center gap-3">
              <div className="text-purple-500">
                <Bell size={24} />
              </div>
              <h3 className="text-gray-900 dark:text-white font-medium">Programme</h3>
            </div>
          </div>
          <button 
            onClick={handleShowForm}
            className="w-full bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors flex items-center gap-2 justify-center"
          >
            <Plus size={20} />
            {showAddForm ? 'Masquer le formulaire' : 'Ajouter un programme'}
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            Liste des programmes
          </h2>
          <button 
            onClick={fetchPrograms}
            className="flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors"
            disabled={isRefreshing}
          >
            <RotateCw size={16} className={`${isRefreshing ? 'animate-spin' : ''}`} />
            <span>Actualiser</span>
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left border-b border-gray-200 dark:border-gray-700">
                <th className="pb-3 text-gray-500 dark:text-gray-400">Titre</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Chaîne</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Date</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Période</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Genre</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Audience Réelle</th>
                <th className="pb-3 text-gray-500 dark:text-gray-400">Actions</th>
              </tr>
            </thead>
            <tbody>
              {programs.map((program) => (
                <tr key={program.id} className="border-b border-gray-100 dark:border-gray-800">
                  <td className="py-4 text-gray-900 dark:text-white">{program.name}</td>
                  <td className="py-4 text-gray-900 dark:text-white">{program.channel}</td>
                  <td className="py-4 text-gray-900 dark:text-white">
                    {new Date(program.air_date).toLocaleDateString('fr-FR')}
                  </td>
                  <td className="py-4 text-gray-900 dark:text-white">{program.broadcast_period}</td>
                  <td className="py-4 text-gray-900 dark:text-white">{program.genre}</td>
                  <td className="py-4 text-gray-900 dark:text-white">
                    {program.real_audience !== null ? 
                      `${program.real_audience.toFixed(2)}M` : 
                      '-'
                    }
                  </td>
                  <td className="py-4">
                    <div className="flex gap-2">
                      <button 
                        onClick={() => handleEdit(program as Program)}
                        className="p-2 text-purple-500 hover:text-purple-600 hover:bg-purple-100 dark:hover:bg-purple-900/20 rounded-lg transition-colors"
                      >
                        <PenLine size={16} />
                      </button>
                      <button 
                        onClick={() => handleDeleteClick(program as Program)}
                        className="p-2 text-red-500 hover:text-red-600 hover:bg-red-100 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        {showAddForm && (
          <div className="mt-8 border-t border-gray-200 dark:border-gray-700 pt-8">
            <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-6">
              {editingProgramId ? 'Modifier le programme' : 'Ajouter un nouveau programme'}
            </h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Titre
                  <span className="text-red-500 ml-1">*</span>
                </label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={(e) => handleChange('title', e.target.value)}
                  className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  placeholder="Titre du programme"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Chaîne
                    <span className="text-red-500 ml-1">*</span>
                  </label>
                  <select
                    required
                    value={formData.channel}
                    onChange={(e) => handleChange('channel', e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  >
                    <option value="">Sélectionner une chaîne</option>
                    <option value="TF1">TF1</option>
                    <option value="France 2">France 2</option>
                    <option value="France 3">France 3</option>
                    <option value="Canal+">Canal+</option>
                    <option value="France 5">France 5</option>
                    <option value="M6">M6</option>
                    <option value="Arte">Arte</option>
                    <option value="C8">C8</option>
                    <option value="W9">W9</option>
                    <option value="TMC">TMC</option>
                    <option value="TFX">TFX</option>
                    <option value="CSTAR">CSTAR</option>
                    <option value="Gulli">Gulli</option>
                    <option value="TF1 Séries Films">TF1 Séries Films</option>
                    <option value="6ter">6ter</option>
                    <option value="RMC Story">RMC Story</option>
                    <option value="RMC Découverte">RMC Découverte</option>
                    <option value="Chérie 25">Chérie 25</option>
                    <option value="L'Équipe">L'Équipe</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Genre
                  </label>
                  <select
                    value={formData.genre}
                    onChange={(e) => handleChange('genre', e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  >
                    <option value="">Sélectionner un genre</option>
                    <option value="Divertissement">Divertissement</option>
                    <option value="Série">Série</option>
                    <option value="Film">Film</option>
                    <option value="Information">Information</option>
                    <option value="Sport">Sport</option>
                    <option value="Documentaire">Documentaire</option>
                    <option value="Magazine">Magazine</option>
                    <option value="Jeunesse">Jeunesse</option>
                  </select>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Date de diffusion
                    <span className="text-red-500 ml-1">*</span>
                  </label>
                  <input
                    type="date"
                    required
                    value={formData.date}
                    onChange={(e) => handleChange('date', e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Période de diffusion
                    <span className="text-red-500 ml-1">*</span>
                  </label>
                  <select
                    required
                    value={formData.period}
                    onChange={(e) => handleChange('period', e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  >
                    <option value="Day">Journée</option>
                    <option value="Access">Access</option>
                    <option value="Prime-time">Prime-time</option>
                    <option value="Night">Nuit</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  URL de l'image
                </label>
                <input
                  type="url"
                  value={formData.imageUrl}
                  onChange={(e) => handleChange('imageUrl', e.target.value)}
                  className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  placeholder="https://..."
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Audience Réelle (en millions)
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={formData.real_audience}
                  onChange={(e) => handleChange('real_audience', e.target.value)}
                  className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                  placeholder="0.00"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => handleChange('description', e.target.value)}
                  className="w-full px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-purple-500 min-h-[100px]"
                  placeholder="Description du programme..."
                />
              </div>

              <div className="flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  onClick={handleShowForm}
                  className="px-4 py-2 rounded-lg bg-gray-100 dark:bg-[#252A34] text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-purple-600 text-white hover:bg-purple-700 transition-colors"
                >
                  {editingProgramId ? 'Mettre à jour' : 'Ajouter'}
                </button>
              </div>
            </form>
          </div>
        )}
      </div>

      <ConfirmationDialog
        isOpen={showDeleteConfirm}
        title="Confirmer la suppression"
        message={`Êtes-vous sûr de vouloir supprimer le programme "${programToDelete?.name}" ? Cette action est irréversible.`}
        confirmLabel="Supprimer"
        cancelLabel="Annuler"
        onConfirm={handleDeleteConfirm}
        onCancel={() => {
          setShowDeleteConfirm(false);
          setProgramToDelete(null);
        }}
      />
    </div>
  );
};

export default AdminPage;