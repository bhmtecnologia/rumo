export interface User {
  id: string;
  email: string;
  name: string;
  profile: string;
  costCenterIds?: string[];
}

export interface RideListItem {
  id: string;
  pickupAddress: string;
  destinationAddress: string;
  pickupLat?: number | null;
  pickupLng?: number | null;
  destinationLat?: number | null;
  destinationLng?: number | null;
  status: string;
  formattedPrice: string;
  createdAt?: string;
  driverName?: string | null;
  vehiclePlate?: string | null;
}

export const RIDE_STATUS_LABEL: Record<string, string> = {
  requested: 'Aguardando motorista',
  accepted: 'Motorista a caminho',
  driver_arrived: 'Motorista chegou',
  in_progress: 'Em viagem',
  completed: 'Finalizada',
  cancelled: 'Cancelada',
};
