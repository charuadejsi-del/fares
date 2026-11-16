import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme.dart';
import '../../i18n.dart';

bool get cameraDisponible =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Écran de scan continu : appareil photo sur téléphone, saisie (ou douchette USB) sur PC.
/// [onCode] est appelé à chaque code lu ; le scan reprend ensuite.
class ScanScreen extends StatefulWidget {
  final String titre;
  final String aide;
  final Future<void> Function(BuildContext context, String code) onCode;
  final bool unSeul;
  const ScanScreen({super.key, required this.titre, required this.onCode, this.aide = 'Visez le QR code de l\'étiquette', this.unSeul = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _ctrl;
  final _saisie = TextEditingController();
  final _focus = FocusNode();
  bool _occupe = false;
  String? _dernier;
  bool _torche = false;

  @override
  void initState() {
    super.initState();
    if (cameraDisponible) {
      _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.all]);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _saisie.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _traiter(String code) async {
    final c = code.trim();
    if (c.isEmpty || _occupe) return;
    setState(() {
      _occupe = true;
      _dernier = c;
    });
    await _ctrl?.stop();
    try {
      await widget.onCode(context, c);
    } finally {
      if (mounted) {
        if (widget.unSeul) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _occupe = false);
          _saisie.clear();
          _focus.requestFocus();
          await _ctrl?.start();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null) {
      // PC : douchette USB ou saisie manuelle
      return Scaffold(
        appBar: AppBar(title: Text(widget.titre)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text('Scannez avec la douchette USB ou tapez la référence'.tr, textAlign: TextAlign.center, style: context.tt.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _saisie,
                  focusNode: _focus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(hintText: 'ex. ROB-0001'.tr, prefixIcon: Icon(Icons.qr_code_2_rounded)),
                  onSubmitted: _traiter,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _occupe ? null : () => _traiter(_saisie.text),
                  icon: const Icon(Icons.search_rounded),
                  label: Text('Valider'.tr),
                ),
                if (_dernier != null) ...[
                  const SizedBox(height: 14),
                  Text('Dernier code : {0}'.trf([_dernier]), style: TextStyle(color: context.pal.muted)),
                ],
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titre, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Lampe'.tr,
            icon: Icon(_torche ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
            onPressed: () async {
              await _ctrl?.toggleTorch();
              setState(() => _torche = !_torche);
            },
          ),
          IconButton(
            tooltip: 'Saisir la référence'.tr,
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
            onPressed: () async {
              final c = TextEditingController();
              final v = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Référence'.tr),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (s) => Navigator.pop(ctx, s),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler'.tr)),
                    FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('OK'.tr)),
                  ],
                ),
              );
              if (v != null) await _traiter(v);
            },
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl!,
          onDetect: (capture) {
            if (_occupe) return;
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (v != null && v.trim().isNotEmpty) {
                _traiter(v);
                break;
              }
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: _occupe ? AppColors.green : Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
              child: Text(_occupe ? 'Code lu : {0}'.trf([_dernier]) : widget.aide, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Scan unique : renvoie le code lu (ou null).
Future<String?> scannerUnCode(BuildContext context, {String titre = 'Scanner'}) async {
  String? lu;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ScanScreen(
      titre: titre,
      unSeul: true,
      onCode: (ctx, code) async => lu = code,
    ),
  ));
  return lu;
}
