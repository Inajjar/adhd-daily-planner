# RevenueCat setup

## Dove appare il paywall

- Dentro l'app quando apri la schermata premium: `lib/features/premium/premium_screen.dart`
- Nei punti premium che aprono quella schermata: `today`, `routines`, `statistics`, `settings`

## Cosa serve nel progetto RevenueCat

1. Public SDK key iOS, formato `appl_...`
2. Entitlement ID: `ADHD_Daily_Pro`
3. Offering corrente: `default`
4. Package mensile di tipo RevenueCat `Monthly`
5. Package annuale di tipo RevenueCat `Annual`
6. Product ID App Store collegati all'offering RevenueCat

## Product ID esatti

Usa questi ID identici su App Store Connect e come prodotti App Store dentro RevenueCat:

```text
MonthlyADHD
yearADHD
```

## Entitlement esatto

```text
ADHD_Daily_Pro
```

## Offering esatto

```text
default
```

## Package esatti dentro l'offering `default`

Nel dashboard RevenueCat non creare package custom con nomi inventati.
Usa i package type predefiniti:

```text
Monthly  -> collega il product `MonthlyADHD`
Annual   -> collega il product `yearADHD`
```

## Flusso che il codice si aspetta

Il codice carica l'offering corrente e cerca:

1. il prodotto con ID `MonthlyADHD`
2. il prodotto con ID `yearADHD`
3. se RevenueCat ha già marcato correttamente i package come `monthly` e `annual`, usa anche quelli come fallback

## File di configurazione locale

Crea una copia locale del template:

```bash
cp revenuecat_config.example.json revenuecat_config.json
```

Poi avvia o builda con:

```bash
flutter run --release --dart-define-from-file=revenuecat_config.json
```

Per iOS archive / ipa:

```bash
flutter build ipa --release --dart-define-from-file=revenuecat_config.json
```

## Nota importante

Se in RevenueCat i prodotti App Store risultano `Missing Metadata`, il paywall puo'
continuare a mostrare `Unavailable` anche con il codice corretto. Prima di testare
su TestFlight assicurati che:

- `MonthlyADHD` sia pronto in App Store Connect
- `yearADHD` sia pronto in App Store Connect
- entrambi siano collegati all'entitlement `ADHD_Daily_Pro`
- entrambi siano nell'offering corrente `default`
