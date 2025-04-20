import React, { useState } from 'react';
import { Check, RefreshCw, ChevronLeft, ChevronRight } from 'lucide-react';

interface AvatarSelectorProps {
  selectedAvatar: string | null;
  onSelect: (url: string) => void;
}

const generateAvatarUrl = (seed: string) => {
  return `https://api.dicebear.com/7.x/pixel-art/svg?seed=${seed}`;
};

const AvatarSelector: React.FC<AvatarSelectorProps> = ({ selectedAvatar, onSelect }) => {
  const [avatars] = useState(() =>
    Array.from({ length: 36 }, (_, i) => generateAvatarUrl(Math.random().toString(36).substring(7)))
  );
  const [currentPage, setCurrentPage] = useState(0);
  const avatarsPerPage = 6;
  const totalPages = Math.ceil(avatars.length / avatarsPerPage);

  const regenerateAvatar = (index: number) => {
    const newUrl = generateAvatarUrl(Math.random().toString(36).substring(7));
    onSelect(newUrl);
  };

  const currentAvatars = avatars.slice(
    currentPage * avatarsPerPage,
    (currentPage + 1) * avatarsPerPage
  );

  const nextPage = () => {
    setCurrentPage((prev) => (prev + 1) % totalPages);
  };

  const prevPage = () => {
    setCurrentPage((prev) => (prev - 1 + totalPages) % totalPages);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between mb-2">
        <span className="block text-sm font-medium text-gray-700 dark:text-gray-300">Avatar (optionnel)</span>
        <div className="flex items-center gap-2">
          <button
            onClick={prevPage}
            className="p-1 text-gray-600 dark:text-gray-300 hover:text-purple-500 dark:hover:text-purple-400 transition-colors disabled:opacity-50"
            disabled={currentPage === 0}
          >
            <ChevronLeft size={20} />
          </button>
          <button
            onClick={nextPage}
            className="p-1 text-gray-600 dark:text-gray-300 hover:text-purple-500 dark:hover:text-purple-400 transition-colors disabled:opacity-50"
            disabled={currentPage === totalPages - 1}
          >
            <ChevronRight size={20} />
          </button>
        </div>
      </div>
      <div className="grid grid-cols-3 gap-4">
        {currentAvatars.map((avatar, index) => (
          <div key={avatar} className="relative group">
            <button
              type="button"
              onClick={() => onSelect(avatar)}
              className={`relative w-full rounded-lg overflow-hidden aspect-square bg-gray-100 dark:bg-gray-800 transition-all ${
                selectedAvatar === avatar 
                  ? 'ring-2 ring-purple-500' 
                  : 'hover:ring-2 hover:ring-purple-500/50'
              }`}
            >
              <img
                src={avatar}
                alt={`Avatar option ${index + 1}`}
                className="w-full h-full object-cover"
              />
              {selectedAvatar === avatar && (
                <div className="absolute inset-0 bg-purple-500/30 flex items-center justify-center">
                  <Check className="text-white" size={24} />
                </div>
              )}
            </button>
            <button
              type="button"
              onClick={() => regenerateAvatar(index)}
              className="absolute top-1 right-1 p-1 bg-white dark:bg-gray-700 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
              title="Générer un nouveau design"
            >
              <RefreshCw size={14} className="text-gray-600 dark:text-gray-300" />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default AvatarSelector;