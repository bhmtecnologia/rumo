import React, { useState, useEffect, useMemo } from 'react';
import { Box, Typography, Paper, Chip, IconButton } from '@mui/material';
import RefreshIcon from '@mui/icons-material/Refresh';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { listRides } from '../api';
import { RIDE_STATUS_LABEL } from '../types';

const DEFAULT_CENTER: [number, number] = [-15.7942, -47.8822];
const DEFAULT_ZOOM = 12;

function FitBounds({ coords }: { coords: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
    if (coords.length === 0) return;
    const bounds = L.latLngBounds(coords);
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 });
  }, [map, coords]);
  return null;
}

const pickupIcon = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});
const destIcon = new L.Icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

export default function Mapa() {
  const [rides, setRides] = useState<Awaited<ReturnType<typeof listRides>>>([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    setLoading(true);
    listRides()
      .then(setRides)
      .catch(() => setRides([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => load(), []);

  const activeRides = rides.filter((r) =>
    ['requested', 'accepted', 'driver_arrived', 'in_progress'].includes(r.status)
  );

  const coords = useMemo(() => {
    const out: [number, number][] = [];
    activeRides.forEach((r) => {
      if (r.pickupLat != null && r.pickupLng != null) out.push([r.pickupLat, r.pickupLng]);
      if (r.destinationLat != null && r.destinationLng != null)
        out.push([r.destinationLat, r.destinationLng]);
    });
    return out;
  }, [activeRides]);

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5">Mapa – corridas e parceiros</Typography>
        <IconButton onClick={load} disabled={loading} title="Atualizar">
          <RefreshIcon />
        </IconButton>
      </Box>
      <Paper variant="outlined" sx={{ overflow: 'hidden', height: 500 }}>
        <MapContainer
          center={DEFAULT_CENTER}
          zoom={DEFAULT_ZOOM}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {coords.length > 0 && <FitBounds coords={coords} />}
          {activeRides.map((r) => (
            <React.Fragment key={r.id}>
              {r.pickupLat != null && r.pickupLng != null && (
                <Marker
                  key={`${r.id}-pickup`}
                  position={[r.pickupLat, r.pickupLng]}
                  icon={pickupIcon}
                >
                  <Popup>
                    <strong>Origem</strong> – {r.pickupAddress}
                    <br />
                    <Chip size="small" label={RIDE_STATUS_LABEL[r.status] || r.status} sx={{ mt: 0.5 }} />
                    {r.driverName && <><br />Motorista: {r.driverName}</>}
                  </Popup>
                </Marker>
              )}
              {r.destinationLat != null && r.destinationLng != null && (
                <Marker
                  key={`${r.id}-dest`}
                  position={[r.destinationLat, r.destinationLng]}
                  icon={destIcon}
                >
                  <Popup>
                    <strong>Destino</strong> – {r.destinationAddress}
                    <br />
                    <Chip size="small" label={RIDE_STATUS_LABEL[r.status] || r.status} sx={{ mt: 0.5 }} />
                  </Popup>
                </Marker>
              )}
            </React.Fragment>
          ))}
        </MapContainer>
      </Paper>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
        Marcadores: origem (azul) e destino das corridas em andamento. A localização em tempo real
        dos parceiros pode ser exibida quando a API disponibilizar.
      </Typography>
    </Box>
  );
}
