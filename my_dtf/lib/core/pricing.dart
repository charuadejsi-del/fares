/// My DTF — calcul du prix (paramètres fixés par l'administrateur).
library;

class PricingSettings {
  /// Prix d'un mètre linéaire de film, en DA.
  final double pricePerMeter;

  /// Montant minimum d'une commande, en DA (0 = aucun).
  final double minOrderAmount;

  /// Pas d'arrondi du métrage facturé, en mètres (ex. 0.1 → 1.512 m → 1.6 m).
  final double meterRoundingStep;

  const PricingSettings({
    required this.pricePerMeter,
    this.minOrderAmount = 0,
    this.meterRoundingStep = 0.1,
  });
}

class Quote {
  final double lengthCm;
  final double billedMeters;
  final double printAmount;
  final double deliveryFee;

  const Quote(this.lengthCm, this.billedMeters, this.printAmount,
      this.deliveryFee);

  double get total => printAmount + deliveryFee;
}

Quote computeQuote(double lengthCm, PricingSettings s,
    {double deliveryFee = 0}) {
  final meters = lengthCm / 100;
  final step = s.meterRoundingStep;
  final billed = step > 0
      ? ((meters / step) - 1e-9).ceil() * step
      : meters;
  final billedRounded = (billed * 1000).roundToDouble() / 1000;
  var amount = billedRounded * s.pricePerMeter;
  if (amount < s.minOrderAmount) amount = s.minOrderAmount;
  return Quote(lengthCm, billedRounded, amount.roundToDouble(), deliveryFee);
}
