import { useState } from 'react';
import styles from './Home.module.css';

export function Home({ onSelectPassenger, onSelectDriver }) {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div className={styles.logo}>
          <span className={styles.logoIcon}>R</span>
          <span className={styles.logoText}>Rumo</span>
        </div>
        <p className={styles.tagline}>Seu transporte, simples</p>
      </header>

      <main className={styles.main}>
        <p className={styles.question}>Como você quer usar o Rumo?</p>
        <div className={styles.choices}>
          <button
            type="button"
            className={styles.choice}
            onClick={onSelectPassenger}
          >
            <span className={styles.choiceIcon}>🧑‍🤝‍🧑</span>
            <span className={styles.choiceLabel}>Sou passageiro</span>
            <span className={styles.choiceHint}>Pedir uma corrida</span>
          </button>
          <button
            type="button"
            className={styles.choice}
            onClick={onSelectDriver}
          >
            <span className={styles.choiceIcon}>🚗</span>
            <span className={styles.choiceLabel}>Sou motorista</span>
            <span className={styles.choiceHint}>Oferecer corridas</span>
          </button>
        </div>
      </main>

      <footer className={styles.footer}>
        Escolha como deseja continuar
      </footer>
    </div>
  );
}
