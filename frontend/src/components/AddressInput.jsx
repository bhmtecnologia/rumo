import { useState, useRef, useEffect, forwardRef } from 'react';
import { searchAddress } from '../lib/nominatim';
import styles from './AddressInput.module.css';

export const AddressInput = forwardRef(function AddressInput({
  value,
  onChange,
  onSelect,
  placeholder,
  'data-dot': dataDot,
  hideMarker,
  disabled,
  className,
  skipSearchOnNextValueChange,
}, ref) {
  const [query, setQuery] = useState(value || '');
  const [suggestions, setSuggestions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const debounceRef = useRef(null);
  const wrapperRef = useRef(null);
  const skipSearchRef = useRef(false);

  useEffect(() => {
    if (skipSearchOnNextValueChange) skipSearchRef.current = true;
    if (value != null && String(value).trim() !== '') skipSearchRef.current = true;
    setQuery(value ?? '');
  }, [value, skipSearchOnNextValueChange]);

  useEffect(() => {
    if (skipSearchRef.current) {
      skipSearchRef.current = false;
      setSuggestions([]);
      setOpen(false);
      return;
    }
    if (!query.trim()) {
      setSuggestions([]);
      setOpen(false);
      return;
    }
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        const list = await searchAddress(query);
        setSuggestions(list);
        setOpen(true);
      } catch {
        setSuggestions([]);
      } finally {
        setLoading(false);
      }
    }, 350);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  useEffect(() => {
    function handleClickOutside(e) {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSelect = (item) => {
    skipSearchRef.current = true;
    setQuery(item.displayName);
    setSuggestions([]);
    setOpen(false);
    onChange?.(item.displayName);
    onSelect?.({ address: item.displayName, lat: item.lat, lng: item.lon });
  };

  return (
    <div className={`${styles.wrapper} ${className || ''}`.trim()} ref={wrapperRef}>
      <div className={styles.inputGroup}>
        {!hideMarker && dataDot && <span className={styles.dot} data-dot={dataDot} />}
        <input
          ref={ref}
          type="text"
          className={styles.input}
          placeholder={placeholder}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => suggestions.length > 0 && setOpen(true)}
          disabled={disabled}
          autoComplete="off"
        />
        {loading && <span className={styles.spinner} />}
      </div>
      {open && suggestions.length > 0 && (
        <ul className={styles.suggestions}>
          {suggestions.map((item, i) => (
            <li key={i}>
              <button
                type="button"
                className={styles.suggestionItem}
                onClick={() => handleSelect(item)}
              >
                {item.displayName}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
});
