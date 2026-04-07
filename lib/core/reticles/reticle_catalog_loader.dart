import 'dart:convert';

import 'package:flutter/services.dart';

import 'reticle_definition.dart';

class ReticleCatalogLoader {
  static const assetPath = 'assets/reticles/reticle_catalog.json';

  static Future<List<ReticleDefinition>> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ReticleDefinition.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
