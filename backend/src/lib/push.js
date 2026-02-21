/**
 * Envio de push notifications via Firebase Cloud Messaging (FCM).
 * Requer FIREBASE_SERVICE_ACCOUNT_JSON (conteúdo do JSON) ou FIREBASE_SERVICE_ACCOUNT_PATH (caminho do arquivo).
 * Se não configurado, as funções retornam sem erro (graceful degradation).
 */
import { readFileSync } from 'fs';
import { join } from 'path';

let admin = null;

function getServiceAccount() {
  const jsonEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (jsonEnv && jsonEnv.trim()) {
    try {
      return JSON.parse(jsonEnv);
    } catch (err) {
      console.error('FCM: FIREBASE_SERVICE_ACCOUNT_JSON inválido:', err.message);
      return null;
    }
  }
  const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!path) return null;
  try {
    return JSON.parse(
      readFileSync(path.startsWith('/') ? path : join(process.cwd(), path), 'utf8')
    );
  } catch (err) {
    console.error('FCM: erro ao ler arquivo:', err.message);
    return null;
  }
}

async function getMessaging() {
  if (admin) return admin.messaging();
  const serviceAccount = getServiceAccount();
  if (!serviceAccount) {
    console.warn('FCM: FIREBASE_SERVICE_ACCOUNT_JSON ou FIREBASE_SERVICE_ACCOUNT_PATH não configurado. Push desabilitado.');
    return null;
  }
  try {
    const fcm = await import('firebase-admin');
    admin = fcm.default;
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    }
    return admin.messaging();
  } catch (err) {
    console.error('FCM init error:', err.message);
    return null;
  }
}

/**
 * Envia push para motoristas quando uma nova corrida é criada.
 * @param {string[]} tokens - Tokens FCM dos motoristas
 * @param {object} ride - { id, pickupAddress, destinationAddress, formattedPrice }
 */
export async function sendNewRideNotificationToDrivers(tokens, ride) {
  if (!tokens?.length) return;
  const messaging = await getMessaging();
  if (!messaging) return;
  try {
    const message = {
      notification: {
        title: 'Nova corrida disponível',
        body: `${ride.pickupAddress ?? 'Origem'} → ${ride.destinationAddress ?? 'Destino'} • ${ride.formattedPrice ?? ''}`,
      },
      data: {
        type: 'new_ride',
        rideId: String(ride.id),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'rumo_new_ride',
          sound: 'default',
          priority: 'max',
        },
      },
      tokens,
    };
    const result = await messaging.sendEachForMulticast(message);
    console.log('[push] FCM enviado:', result.successCount, 'ok,', result.failureCount, 'falhas');
    if (result.failureCount > 0) {
      result.responses.forEach((resp, i) => {
        if (!resp.success) console.warn('[push] FCM falhou:', resp.error?.message, 'token:', tokens[i]?.slice(0, 20) + '...');
      });
    }
  } catch (err) {
    console.error('FCM send error:', err.message);
  }
}

/**
 * Envia push para o passageiro quando motorista aceita a corrida.
 * @param {string[]} tokens - Tokens FCM do passageiro
 * @param {object} ride - { id, driverName, vehiclePlate }
 */
export async function sendDriverAcceptedNotificationToPassenger(tokens, ride) {
  if (!tokens?.length) return;
  const messaging = await getMessaging();
  if (!messaging) return;
  try {
    const body = ride.driverName
      ? `Motorista ${ride.driverName}${ride.vehiclePlate ? ` • ${ride.vehiclePlate}` : ''} aceitou sua corrida`
      : 'Um motorista aceitou sua corrida';
    const message = {
      notification: {
        title: 'Motorista a caminho!',
        body,
      },
      data: {
        type: 'driver_accepted',
        rideId: String(ride.id),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'rumo_driver_accepted',
          sound: 'default',
          priority: 'max',
        },
      },
      tokens,
    };
    const result = await messaging.sendEachForMulticast(message);
    console.log('[push] FCM passageiro:', result.successCount, 'ok,', result.failureCount, 'falhas');
  } catch (err) {
    console.error('FCM passageiro error:', err.message);
  }
}
