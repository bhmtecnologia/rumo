import { useState, useCallback, useEffect } from 'react';
import { MapContainer, TileLayer, useMapEvents, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { reverseGeocode } from '../lib/nominatim';
import styles from './MapPickerScreen.module.css';

const DEFAULT_CENTER = [-23.5505, -46.6333];
const DEFAULT_ZOOM = 14;

function MapCenterTracker({ onCenterChange }) {
  const map = useMap();
  useEffect(() => {
    const c = map.getCenter();
    onCenterChange(c.lat, c.lng);
  }, [map, onCenterChange]);
  useMapEvents({
    moveend() {
      const c = this.getCenter();
      onCenterChange(c.lat, c.lng);
    },
  });
  return null;
}

export function MapPickerScreen({ initialCenter, onConfirm, onBack }) {
  const [center, setCenter] = useState(() => {
    if (initialCenter?.lat != null) return [initialCenter.lat, initialCenter.lng];
    return DEFAULT_CENTER;
  });
  const [address, setAddress] = useState('');
  const [loading, setLoading] = useState(false);
  const [confirming, setConfirming] = useState(false);

  const handleCenterChange = useCallback((lat, lng) => {
    setCenter([lat, lng]);
  }, []);

  const handleConfirm = useCallback(async () => {
    setConfirming(true);
    setLoading(true);
    try {
      const [lat, lng] = center;
      const addr = await reverseGeocode(lat, lng);
      setAddress(addr || '');
      onConfirm({ lat, lng, address: addr || `${lat.toFixed(5)}, ${lng.toFixed(5)}` });
    } catch {
      onConfirm({ lat: center[0], lng: center[1], address: `${center[0].toFixed(5)}, ${center[1].toFixed(5)}` });
    } finally {
      setLoading(false);
      setConfirming(false);
    }
  }, [center, onConfirm]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <button type="button" className={styles.back} onClick={onBack}>
          ← Voltar
        </button>
        <span className={styles.title}>Insira seu destino</span>
      </header>

      <div className={styles.mapWrap}>
        <MapContainer
          center={center}
          zoom={DEFAULT_ZOOM}
          className={styles.map}
          scrollWheelZoom={true}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <MapCenterTracker onCenterChange={handleCenterChange} />
        </MapContainer>
        <div className={styles.centerMarker} aria-hidden>
          <span className={styles.centerMarkerPin} />
        </div>
      </div>

      <div className={styles.panel}>
        <p className={styles.instruction}>
          Arraste o mapa para mover o marcador
        </p>
        <div className={styles.searchRow}>
          <span className={styles.inputIcon}>▢</span>
          <input
            type="text"
            className={styles.input}
            placeholder="Para onde?"
            value={address}
            readOnly
            aria-label="Endereço do ponto selecionado"
          />
          <span className={styles.searchIcon}>🔍</span>
        </div>
        <button
          type="button"
          className={styles.confirmBtn}
          onClick={handleConfirm}
          disabled={confirming || loading}
        >
          {loading ? 'Buscando endereço...' : 'Confirmar destino'}
        </button>
      </div>
    </div>
  );
}
