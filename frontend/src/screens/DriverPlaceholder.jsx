import styles from './DriverPlaceholder.module.css';

export function DriverPlaceholder({ onBack }) {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <button type="button" className={styles.back} onClick={onBack}>
          ← Voltar
        </button>
        <div className={styles.logo}>
          <span className={styles.logoIcon}>R</span>
          <span className={styles.logoText}>Rumo</span>
        </div>
      </header>
      <main className={styles.main}>
        <span className={styles.emoji}>🚗</span>
        <h1 className={styles.title}>Área do motorista</h1>
        <p className={styles.text}>
          Em breve você poderá aceitar corridas e enviar sua localização por aqui.
        </p>
        <button type="button" className={styles.btnBack} onClick={onBack}>
          Voltar ao início
        </button>
      </main>
    </div>
  );
}
