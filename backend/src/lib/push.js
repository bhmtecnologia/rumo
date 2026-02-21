/**
 * Envio de push notifications via Firebase Cloud Messaging (FCM).
 * Requer FIREBASE_SERVICE_ACCOUNT_PATH apontando para o JSON da service account.
 * Se não configurado, as funções retornam sem erro (graceful degradation).
 */
import { readFileSync } from 'fs';
import { join } from 'path';

let admin = null;

async function getMessaging() {
  if (admin) return admin.messaging();
  const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!path) {
    console.warn('FCM: FIREBASE_SERVICE_ACCOUNT_PATH não configurado. Push desabilitado.');
    return null;
  }
  try {
    const serviceAccount = JSON.parse(
      readFileSync(path.startsWith('/') ? path : join(process.cwd(), path), 'utf8')
    );
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
    if (result.failureCount > 0) {
      result.responses.forEach((resp, i) => {
        if (!resp.success) console.warn('FCM send failed:', resp.error?.message, 'token:', tokens[i]?.slice(0, 20) + '...');
      });
    }
  } catch (err) {
    console.error('FCM send error:', err.message);
  }
}
