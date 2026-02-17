import styles from './RideConfirmation.module.css';

const statusLabel = {
  requested: 'Solicitada',
  accepted: 'Aceita',
  in_progress: 'Em andamento',
  completed: 'Concluída',
  cancelled: 'Cancelada',
};

export function RideConfirmation({ ride, onNewRide }) {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div className={styles.logo}>
          <span className={styles.logoIcon}>R</span>
          <span className={styles.logoText}>Rumo</span>
        </div>
      </header>

      <main className={styles.main}>
        <div className={styles.card}>
          <div className={styles.successIcon}>✓</div>
          <h1 className={styles.title}>Corrida solicitada</h1>
          <p className={styles.subtitle}>
            Sua solicitação foi registrada. Em breve um motorista poderá aceitar.
          </p>

          <div className={styles.details}>
            <div className={styles.route}>
              <span className={styles.dotOrigin} />
              <div>
                <div className={styles.label}>Embarque</div>
                <div className={styles.address}>{ride.pickup_address}</div>
              </div>
            </div>
            <div className={styles.routeLine} />
            <div className={styles.route}>
              <span className={styles.dotDest} />
              <div>
                <div className={styles.label}>Destino</div>
                <div className={styles.address}>{ride.destination_address}</div>
              </div>
            </div>
          </div>

          <div className={styles.meta}>
            <div className={styles.metaRow}>
              <span>Status</span>
              <span className={styles.status}>{statusLabel[ride.status] || ride.status}</span>
            </div>
            <div className={styles.metaRow}>
              <span>Distância</span>
              <span>{ride.estimated_distance_km} km</span>
            </div>
            <div className={styles.metaRow}>
              <span>Tempo est.</span>
              <span>{ride.estimated_duration_min} min</span>
            </div>
            <div className={styles.priceRow}>
              <span>Valor estimado</span>
              <strong>{ride.formattedPrice}</strong>
            </div>
          </div>

          <p className={styles.id}>ID da corrida: {ride.id}</p>

          <button type="button" className={styles.btnNew} onClick={onNewRide}>
            Nova corrida
          </button>
        </div>
      </main>
    </div>
  );
}
