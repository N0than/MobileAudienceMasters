import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

const AdminAccess = () => {
  const [pin, setPin] = useState(['', '', '', '']);
  const navigate = useNavigate();
  const [error, setError] = useState('');

  const handlePinChange = (value: string, index: number) => {
    if (value.length <= 1 && /^\d*$/.test(value)) {
      setError('');
      const newPin = [...pin];
      newPin[index] = value;
      setPin(newPin);

      // Auto-focus next input
      if (value && index < 3) {
        const nextInput = document.getElementById(`pin-${index + 1}`);
        nextInput?.focus();
      }

      // Check PIN when all digits are entered
      if (index === 3 && value) {
        const enteredPin = [...newPin.slice(0, 3), value].join('');
        if (enteredPin === '1987') {
          navigate('/admin/dashboard');
        } else {
          setError('Code PIN incorrect');
          setPin(['', '', '', '']);
          document.getElementById('pin-0')?.focus();
        }
      }
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
    if (e.key === 'Backspace' && !pin[index] && index > 0) {
      const prevInput = document.getElementById(`pin-${index - 1}`);
      prevInput?.focus();
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-[#131720]">
      <div className="bg-white dark:bg-[#1B2028] p-8 rounded-lg shadow-lg max-w-md w-full">
        <h2 className="text-2xl font-bold text-center text-gray-900 dark:text-white mb-6">
          Accès Administration
        </h2>
        {error && (
          <div className="text-red-500 text-center mb-4">
            {error}
          </div>
        )}
        <div className="flex justify-center gap-4 mb-8">
          {pin.map((digit, index) => (
            <input
              key={index}
              id={`pin-${index}`}
              type="password"
              value={digit}
              onChange={(e) => handlePinChange(e.target.value, index)}
              onKeyDown={(e) => handleKeyDown(e, index)}
              className="w-12 h-12 text-center text-2xl font-bold bg-gray-100 dark:bg-[#252A34] border-2 border-gray-300 dark:border-gray-700 rounded-lg focus:outline-none focus:border-purple-500 dark:focus:border-purple-500 text-gray-900 dark:text-white"
              maxLength={1}
            />
          ))}
        </div>
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((number) => (
            <button
              key={number}
              onClick={() => {
                const emptyIndex = pin.findIndex(digit => digit === '');
                if (emptyIndex !== -1) {
                  handlePinChange(number.toString(), emptyIndex);
                }
              }}
              className="w-full h-12 rounded-lg bg-gray-100 dark:bg-[#252A34] text-gray-900 dark:text-white font-semibold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
            >
              {number}
            </button>
          ))}
          <button
            onClick={() => setPin(['', '', '', ''])}
            className="w-full h-12 rounded-lg bg-gray-100 dark:bg-[#252A34] text-gray-900 dark:text-white font-semibold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          >
            Effacer
          </button>
          <button
            onClick={() => {
              const emptyIndex = pin.findIndex(digit => digit === '');
              if (emptyIndex !== -1) {
                handlePinChange('0', emptyIndex);
              }
            }}
            className="w-full h-12 rounded-lg bg-gray-100 dark:bg-[#252A34] text-gray-900 dark:text-white font-semibold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          >
            0
          </button>
          <button
            onClick={() => {
              const enteredPin = pin.join('');
              if (enteredPin === '1987') {
                navigate('/admin/dashboard');
              } else {
                setError('Code PIN incorrect');
                setPin(['', '', '', '']);
                document.getElementById('pin-0')?.focus();
              }
            }}
            className="w-full h-12 rounded-lg bg-purple-600 text-white font-semibold hover:bg-purple-700 transition-colors"
          >
            Valider
          </button>
        </div>
      </div>
    </div>
  );
};

export default AdminAccess;