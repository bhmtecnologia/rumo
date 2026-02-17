import { useMemo, useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { getRoutePolyline } from '../lib/osrm';
import styles from './RideMap.module.css';

// Corrige ícones padrão do Leaflet no bundler
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

const DEFAULT_CENTER = [-23.5505, -46.6333];
const DEFAULT_ZOOM = 12;

function FitBounds({ pickup, destination }) {
  const map = useMap();
  const hasBoth = pickup?.lat != null && destination?.lat != null;
  useEffect(() => {
    if (!hasBoth) return;
    const bounds = L.latLngBounds(
      [pickup.lat, pickup.lng],
      [destination.lat, destination.lng]
    );
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 });
  }, [map, pickup, destination, hasBoth]);
  return null;
}

function SetViewOnLocation({ center, whenNoBounds }) {
  const map = useMap();
  useEffect(() => {
    if (!whenNoBounds && center) map.setView(center, map.getZoom());
  }, [map, center, whenNoBounds]);
  return null;
}

function MapClickHandler({ onMapClick, active }) {
  useMapEvents({
    click(e) {
      if (active && onMapClick) onMapClick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

export function RideMap({ pickup, destination, userLocation, className, onMapClick, mapPickerActive }) {
  const hasBounds = pickup?.lat != null && destination?.lat != null;
  const center = useMemo(() => {
    if (pickup?.lat != null) return [pickup.lat, pickup.lng];
    if (destination?.lat != null) return [destination.lat, destination.lng];
    if (userLocation?.lat != null) return [userLocation.lat, userLocation.lng];
    return DEFAULT_CENTER;
  }, [pickup, destination, userLocation]);

  const [routePositions, setRoutePositions] = useState([]);

  useEffect(() => {
    if (pickup?.lat == null || destination?.lat == null) {
      setRoutePositions([]);
      return;
    }
    let cancelled = false;
    getRoutePolyline(pickup.lat, pickup.lng, destination.lat, destination.lng)
      .then((positions) => {
        if (!cancelled && Array.isArray(positions) && positions.length > 0) {
          setRoutePositions(positions);
        } else if (!cancelled) {
          setRoutePositions([
            [pickup.lat, pickup.lng],
            [destination.lat, destination.lng],
          ]);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setRoutePositions([
            [pickup.lat, pickup.lng],
            [destination.lat, destination.lng],
          ]);
        }
      });
    return () => { cancelled = true; };
  }, [pickup?.lat, pickup?.lng, destination?.lat, destination?.lng]);

  const hasRoute = routePositions.length >= 2;

  return (
    <div className={`${styles.mapWrap} ${className || ''} ${mapPickerActive ? styles.pickerActive : ''}`}>
      {mapPickerActive && (
        <div className={styles.pickerBanner}>
          Toque no mapa para definir o ponto
        </div>
      )}
      <MapContainer
        center={center}
        zoom={DEFAULT_ZOOM}
        className={styles.map}
        scrollWheelZoom={true}
      >
        <MapClickHandler onMapClick={onMapClick} active={mapPickerActive} />
        <SetViewOnLocation center={center} whenNoBounds={hasBounds} />
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {hasRoute && (
          <Polyline
            positions={routePositions}
            pathOptions={{
              color: '#e8b84a',
              weight: 5,
              opacity: 0.9,
              lineJoin: 'round',
              lineCap: 'round',
            }}
          />
        )}
        {pickup?.lat != null && (
          <Marker position={[pickup.lat, pickup.lng]}>
            <Popup>Embarque</Popup>
          </Marker>
        )}
        {destination?.lat != null && (
          <Marker position={[destination.lat, destination.lng]}>
            <Popup>Destino</Popup>
          </Marker>
        )}
        <FitBounds pickup={pickup} destination={destination} />
      </MapContainer>
    </div>
  );
}
