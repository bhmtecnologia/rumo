import { useState } from 'react';
import { Home } from './screens/Home';
import { PassengerHome } from './screens/PassengerHome';
import { RequestRide } from './screens/RequestRide';
import { RideConfirmation } from './screens/RideConfirmation';
import { DriverPlaceholder } from './screens/DriverPlaceholder';

export default function App() {
  const [role, setRole] = useState(null);
  const [passengerView, setPassengerView] = useState('home');
  const [ride, setRide] = useState(null);

  if (ride) {
    return (
      <RideConfirmation
        ride={ride}
        onNewRide={() => {
          setRide(null);
          setPassengerView('home');
        }}
      />
    );
  }

  if (role === 'driver') {
    return (
      <DriverPlaceholder onBack={() => setRole(null)} />
    );
  }

  if (role === 'passenger') {
    if (passengerView === 'home') {
      return (
        <PassengerHome
          onBack={() => setRole(null)}
          onStartRide={() => setPassengerView('request')}
        />
      );
    }
    return (
      <RequestRide
        onRideRequested={setRide}
        onBack={() => setPassengerView('home')}
      />
    );
  }

  return (
    <Home
      onSelectPassenger={() => setRole('passenger')}
      onSelectDriver={() => setRole('driver')}
    />
  );
}
