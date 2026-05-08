import 'package:flutter/material.dart';
import 'floating_chem_icons.dart';
import 'glow_ring.dart';
import 'orbital_particles.dart';

class MoleculeVisualArea extends StatelessWidget {
  const MoleculeVisualArea({
    super.key,
    required this.stage,
    this.smiles,
  });

  final int stage;
  final String? smiles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring (visible from stage 2)
          Positioned.fill(
            child: Center(
              child: GlowRing(visible: stage >= 2, size: 170),
            ),
          ),
          // Orbital particles (visible from stage 2)
          Positioned.fill(
            child: Center(
              child: OrbitalParticles(visible: stage >= 2),
            ),
          ),
          // Floating chemistry icons (always visible)
          const Positioned.fill(
            child: FloatingChemIcons(visible: true),
          ),
        ],
      ),
    );
  }
}
