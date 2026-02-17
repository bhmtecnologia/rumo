import { useState, useCallback, useRef, useEffect } from 'react';
import { getEstimate, createRide } from '../api';
import { reverseGeocode, searchAddress } from '../lib/nominatim';
import { AddressInput } from '../components/AddressInput';
import { RideMap } from '../components/RideMap';
import { MapPickerScreen } from './MapPickerScreen';
import styles from './RequestRide.module.css';

export function RequestRide({ onRideRequested, onBack }) {
  const [pickup, setPickup] = useState('');
  const [destination, setDestination] = useState('');
  const [pickupCoords, setPickupCoords] = useState(null);
  const [destinationCoords, setDestinationCoords] = useState(null);
  const [userLocation, setUserLocation] = useState(null);
  const [locationLoading, setLocationLoading] = useState(true);
  const [locationError, setLocationError] = useState(null);
  const destinationInputRef = useRef(null);
  const [estimate, setEstimate] = useState(null);
  const [loading, setLoading] = useState(false);
  const [requesting, setRequesting] = useState(false);
  const [error, setError] = useState('');
  const [mapPickerMode, setMapPickerMode] = useState(null);
  const [showFullScreenMapPicker, setShowFullScreenMapPicker] = useState(false);
  const [skipDestinationSearch, setSkipDestinationSearch] = useState(false);
  const [mapPickFeedback, setMapPickFeedback] = useState(null);
  const mapPickCooldownRef = useRef(false);
  const [view, setView] = useState('form');

  useEffect(() => {
    if (!navigator.geolocation) {
      setLocationLoading(false);
      setLocationError('Seu navegador não suporta localização.');
      return;
    }
    setLocationLoading(true);
    setLocationError(null);
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        setUserLocation({ lat, lng });
        setPickupCoords({ lat, lng });
        setPickup('Obtendo endereço...');
        setLocationLoading(false);
        try {
          const address = await reverseGeocode(lat, lng);
          setPickup(address || 'Minha localização');
        } catch {
          setPickup('Minha localização');
        }
        setTimeout(() => destinationInputRef.current?.focus(), 150);
      },
      (err) => {
        setLocationLoading(false);
        if (err.code === 1) {
          setLocationError('Ative a localização no navegador para usar sua posição como origem.');
        } else if (err.code === 3) {
          setLocationError('Tempo esgotado. Ative o GPS e tente de novo.');
        } else {
          setLocationError('Não foi possível obter sua localização.');
        }
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    );
  }, []);

  const canEstimate = pickup.trim() && destination.trim();
  const hasCoords = pickupCoords && destinationCoords;

  const openTripChoiceWithDestination = useCallback(async (destAddress, destCoords) => {
    if (!pickup?.trim() || !destAddress?.trim()) return;
    setDestination(destAddress);
    setDestinationCoords(destCoords);
    setEstimate(null);
    setError('');
    setLoading(true);
    try {
      const body = {
        pickupAddress: pickup.trim(),
        destinationAddress: destAddress.trim(),
      };
      if (pickupCoords?.lat != null) {
        body.pickupLat = pickupCoords.lat;
        body.pickupLng = pickupCoords.lng;
      }
      if (destCoords?.lat != null) {
        body.destinationLat = destCoords.lat;
        body.destinationLng = destCoords.lng;
      }
      const data = await getEstimate(body);
      setEstimate(data);
      setView('tripChoice');
    } catch (e) {
      setError(e.message);
      setEstimate(null);
    } finally {
      setLoading(false);
    }
  }, [pickup, pickupCoords]);

  const handleRequestRide = useCallback(async () => {
    if (!estimate) return;
    setError('');
    setRequesting(true);
    try {
      const body = {
        pickupAddress: pickup.trim(),
        destinationAddress: destination.trim(),
        estimatedPriceCents: estimate.estimatedPriceCents,
        estimatedDistanceKm: estimate.distanceKm,
        estimatedDurationMin: estimate.durationMin,
      };
      if (pickupCoords?.lat != null) {
        body.pickupLat = pickupCoords.lat;
        body.pickupLng = pickupCoords.lng;
      }
      if (destinationCoords?.lat != null) {
        body.destinationLat = destinationCoords.lat;
        body.destinationLng = destinationCoords.lng;
      }
      const ride = await createRide(body);
      onRideRequested(ride);
    } catch (e) {
      setError(e.message);
    } finally {
      setRequesting(false);
    }
  }, [estimate, pickup, destination, pickupCoords, destinationCoords, onRideRequested]);

  const handleMapPick = useCallback(async (lat, lng) => {
    if (!mapPickerMode || mapPickCooldownRef.current) return;
    mapPickCooldownRef.current = true;
    setMapPickerMode(null);
    setError('');
    try {
      const address = await reverseGeocode(lat, lng);
      if (mapPickerMode === 'destination') {
        setSkipDestinationSearch(true);
        setDestination(address || `${lat.toFixed(5)}, ${lng.toFixed(5)}`);
        setDestinationCoords({ lat, lng });
        setMapPickFeedback('Destino definido no mapa');
      } else {
        setPickup(address || `${lat.toFixed(5)}, ${lng.toFixed(5)}`);
        setPickupCoords({ lat, lng });
        setMapPickFeedback('Embarque definido no mapa');
      }
      setEstimate(null);
    } catch {
      setError('Não foi possível obter o endereço. Tente outro ponto.');
    }
    setTimeout(() => {
      mapPickCooldownRef.current = false;
    }, 600);
    setTimeout(() => setMapPickFeedback(null), 2500);
  }, [mapPickerMode]);

  useEffect(() => {
    if (!skipDestinationSearch || !destination) return;
    const t = setTimeout(() => setSkipDestinationSearch(false), 150);
    return () => clearTimeout(t);
  }, [skipDestinationSearch, destination]);

  const sugestoesDestino = [
    { id: '1', icon: '🕐', nome: 'Sqs 303 - Bloco H', endereco: 'SHCS SQS 303 - Asa Sul, Brasília - DF', distancia: '6,5 km' },
    { id: '2', icon: '✈️', nome: 'Aeroporto Internacional de Brasília', endereco: 'Lago Sul, Brasília - DF', distancia: '5,5 km' },
    { id: '3', icon: '🕐', nome: 'Ed. The Union office', endereco: 'Brasília - DF', distancia: '4,6 km' },
    { id: '4', icon: '🕐', nome: 'Pizza à Bessa', endereco: 'Brasília - DF', distancia: '1,1 km' },
  ];

  if (showFullScreenMapPicker) {
    return (
      <MapPickerScreen
        initialCenter={userLocation || pickupCoords}
        onConfirm={({ lat, lng, address }) => {
          setSkipDestinationSearch(true);
          setShowFullScreenMapPicker(false);
          setMapPickFeedback(null);
          openTripChoiceWithDestination(address, { lat, lng });
        }}
        onBack={() => setShowFullScreenMapPicker(false)}
      />
    );
  }

  if (view === 'tripChoice' && estimate) {
    return (
      <div className={`${styles.page} ${styles.pageTripChoice}`}>
        <header className={styles.headerTripChoice}>
          <button type="button" className={styles.back} onClick={() => setView('form')} aria-label="Voltar">
            ←
          </button>
        </header>
        <div className={styles.tripChoiceMapWrap}>
          <RideMap
            pickup={pickupCoords}
            destination={destinationCoords}
            userLocation={userLocation}
            className={styles.tripChoiceMap}
          />
        </div>
        <div className={styles.tripChoicePanel}>
          <h2 className={styles.chooseTripTitle}>Escolher uma viagem</h2>
          <div className={styles.tripCard}>
            <div className={styles.tripCardHeader}>
              <span className={styles.tripCardIcon}>🚗</span>
              <div className={styles.tripCardInfo}>
                <span className={styles.tripCardName}>Rumo</span>
                <span className={styles.tripCardMeta}>4 passageiros</span>
              </div>
              <div className={styles.tripCardRight}>
                <span className={styles.tripCardTime}>{estimate.durationMin} min</span>
                <strong className={styles.tripCardPrice}>{estimate.formattedPrice}</strong>
              </div>
            </div>
            <p className={styles.tripCardBadge}>Mais rápido</p>
          </div>
          <button
            type="button"
            className={styles.btnChooseTrip}
            onClick={handleRequestRide}
            disabled={requesting}
          >
            {requesting ? 'Solicitando...' : 'Escolha Rumo'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <button type="button" className={styles.back} onClick={onBack} aria-label="Voltar">
          ←
        </button>
        <h1 className={styles.headerTitle}>Planeje sua próxima viagem</h1>
        <div className={styles.headerActions}>
          <button type="button" className={styles.headerBtn}>
            <span>🕐</span> Ir agora
          </button>
          <button type="button" className={styles.headerBtn}>
            <span>👤</span> Para mim
          </button>
        </div>
      </header>

      <main className={styles.main}>
        {locationLoading && (
          <p className={styles.locationStatus}>
            <span className={styles.locationSpinner} /> Obtendo sua localização...
          </p>
        )}
        {locationError && !locationLoading && (
          <p className={styles.locationError}>
            {locationError}
          </p>
        )}
        {mapPickFeedback && (
          <p className={styles.mapPickFeedback}>
            {mapPickFeedback}
          </p>
        )}
        <div className={styles.mapSection}>
          <RideMap
            pickup={pickupCoords}
            destination={destinationCoords}
            userLocation={userLocation}
            onMapClick={handleMapPick}
            mapPickerActive={mapPickerMode !== null}
          />
        </div>

        <div className={styles.cardRoute}>
          <div className={styles.routeColLine}>
            <span className={styles.routeDot} />
            <span className={styles.routeLine} />
            <span className={styles.routeSquare} />
          </div>
          <div className={styles.routeColInputs}>
            <div className={styles.routeRow}>
              <AddressInput
                className={styles.routeInput}
                value={pickup}
                onChange={setPickup}
                onSelect={({ address, lat, lng }) => {
                  setPickup(address);
                  setPickupCoords({ lat, lng });
                  setEstimate(null);
                  setTimeout(() => destinationInputRef.current?.focus(), 0);
                }}
                placeholder={locationLoading ? 'Obtendo sua localização...' : 'Embarque'}
                data-dot="origin"
                hideMarker
                disabled={locationLoading}
              />
              <button type="button" className={styles.routeAdd} title="Adicionar parada (em breve)">
                +
              </button>
            </div>
            <div className={styles.routeRow}>
              <AddressInput
                ref={destinationInputRef}
                className={styles.routeInput}
                value={destination}
                onChange={setDestination}
                onSelect={({ address, lat, lng }) => {
                  setSkipDestinationSearch(true);
                  openTripChoiceWithDestination(address, { lat, lng });
                }}
                placeholder="Para onde?"
                data-dot="destination"
                hideMarker
                skipSearchOnNextValueChange={skipDestinationSearch}
              />
            </div>
          </div>
        </div>

        <section className={styles.sugestoesSection}>
          {sugestoesDestino.map((s) => (
            <button
              key={s.id}
              type="button"
              className={styles.sugestaoItem}
              onClick={async () => {
                const results = await searchAddress(s.endereco);
                if (results?.[0]) {
                  openTripChoiceWithDestination(s.nome, { lat: results[0].lat, lng: results[0].lon });
                } else {
                  setError('Endereço não encontrado. Tente outro ou pesquise no campo acima.');
                }
              }}
            >
              <span className={styles.sugestaoIcon}>{s.icon}</span>
              <div className={styles.sugestaoText}>
                <span className={styles.sugestaoNome}>{s.nome}</span>
                <span className={styles.sugestaoEndereco}>{s.endereco}</span>
              </div>
              <span className={styles.sugestaoDistancia}>{s.distancia}</span>
            </button>
          ))}
          <button type="button" className={styles.opcaoLista}>
            <span className={styles.opcaoListaIcon}>🌐</span>
            Pesquisar em uma cidade diferente
          </button>
          <button
            type="button"
            className={styles.opcaoLista}
            onClick={() => setShowFullScreenMapPicker(true)}
          >
            <span className={styles.opcaoListaIcon}>📍</span>
            Defina a localização no mapa
          </button>
          <button type="button" className={styles.opcaoLista} title="Em breve">
            <span className={styles.opcaoListaIcon}>⭐</span>
            Locais salvos
          </button>
        </section>

        {error && <p className={styles.error}>{error}</p>}

        {loading && (
          <p className={styles.locationStatus}>
            <span className={styles.locationSpinner} /> Calculando rota...
          </p>
        )}
      </main>
    </div>
  );
}
