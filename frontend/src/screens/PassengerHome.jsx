import styles from './PassengerHome.module.css';

const SUGESTOES = [
  { id: 'viagem', icon: '🚗', label: 'Viagem', desc: 'Pedir uma corrida' },
  { id: 'enviar', icon: '📦', label: 'Enviar itens', desc: 'Em breve' },
  { id: 'reserve', icon: '📅', label: 'Reserve', desc: 'Em breve' },
];

const DESTINOS_RECENTES = [
  { id: '1', icon: '🕐', nome: 'Casa', endereco: 'Adicione seu endereço em Opções' },
  { id: '2', icon: '✈️', nome: 'Aeroporto mais próximo', endereco: 'Pesquise para ver opções' },
];

export function PassengerHome({ onBack, onStartRide }) {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <button type="button" className={styles.backBtn} onClick={onBack} aria-label="Voltar">
          ←
        </button>
        <div className={styles.logo}>
          <span className={styles.logoIcon}>R</span>
          <span className={styles.logoText}>Rumo</span>
        </div>
      </header>

      <nav className={styles.tabs}>
        <button type="button" className={styles.tabActive}>
          <span className={styles.tabIcon}>🚗</span>
          Corrida
        </button>
        <button type="button" className={styles.tab}>
          <span className={styles.tabIcon}>📦</span>
          Envios
        </button>
      </nav>

      <main className={styles.main}>
        <div className={styles.searchRow}>
          <button
            type="button"
            className={styles.searchBar}
            onClick={onStartRide}
          >
            <span className={styles.searchIcon}>🔍</span>
            <span className={styles.searchPlaceholder}>Para onde?</span>
          </button>
          <button type="button" className={styles.maisTarde} disabled title="Em breve">
            <span className={styles.maisTardeIcon}>📅</span>
            Mais tarde
          </button>
        </div>

        <section className={styles.section}>
          {DESTINOS_RECENTES.map((dest) => (
            <button
              key={dest.id}
              type="button"
              className={styles.destinoCard}
              onClick={onStartRide}
            >
              <span className={styles.destinoIcon}>{dest.icon}</span>
              <div className={styles.destinoText}>
                <span className={styles.destinoNome}>{dest.nome}</span>
                <span className={styles.destinoEndereco}>{dest.endereco}</span>
              </div>
            </button>
          ))}
        </section>

        <section className={styles.section}>
          <div className={styles.sectionHeader}>
            <h2 className={styles.sectionTitle}>Sugestões</h2>
            <span className={styles.sectionArrow}>→</span>
          </div>
          <div className={styles.sugestoesGrid}>
            {SUGESTOES.map((s) => (
              <button
                key={s.id}
                type="button"
                className={s.id === 'viagem' ? styles.sugestaoCardPrimary : styles.sugestaoCard}
                onClick={s.id === 'viagem' ? onStartRide : undefined}
                disabled={s.id !== 'viagem'}
                title={s.id !== 'viagem' ? s.desc : undefined}
              >
                <span className={styles.sugestaoIcon}>{s.icon}</span>
                <span className={styles.sugestaoLabel}>{s.label}</span>
              </button>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Mais formas de usar o app</h2>
          <div className={styles.maisFormas}>
            <div className={styles.maisFormasCard}>
              <div className={styles.maisFormasPlaceholder}>
                <span>🚗</span>
                <p>Corridas, envios e mais em breve.</p>
              </div>
            </div>
          </div>
        </section>
      </main>

      <nav className={styles.bottomNav}>
        <button type="button" className={styles.navItemActive}>
          <span className={styles.navIcon}>🏠</span>
          <span>Página inicial</span>
        </button>
        <button type="button" className={styles.navItem}>
          <span className={styles.navIcon}>⋮⋮</span>
          <span>Opções</span>
        </button>
        <button type="button" className={styles.navItem}>
          <span className={styles.navIcon}>📋</span>
          <span>Atividade</span>
        </button>
        <button type="button" className={styles.navItem}>
          <span className={styles.navIcon}>👤</span>
          <span>Conta</span>
        </button>
      </nav>
    </div>
  );
}
