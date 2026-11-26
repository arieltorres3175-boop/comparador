class ProductFacets {
  static const categories = <String, String>{
    'Leche': 'leche', 'Café': 'cafe', 'Manteca': 'manteca',
    'Aceite': 'aceite', 'Yogur': 'yogur', 'Queso': 'queso',
    'Crema': 'crema', 'Azúcar': 'azucar', 'Arroz': 'arroz',
    'Fideos': 'fideos',
  };

  static String normalize(String value) => value
      .toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e')
      .replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  static bool isCategoryProduct(String category, String value) {
    final text = normalize(value);
    final words = text.split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).toSet();
    if (category == 'Leche') {
      if (!words.contains('leche')) return false;
      if (text.trimLeft().startsWith('leche ')) return true;
      const milkDescriptors = {
        'entera', 'descremada', 'semidescremada', 'liviana', 'protein',
        'fortificada', 'chocolatada', 'sachet', 'lactosa', 'multidefensa',
        'larga', 'uat', 'fresca', 'polvo',
      };
      return words.any(milkDescriptors.contains) ||
          RegExp(r'\d+(?:[.,]\d+)?\s?(?:l|lt|litro|litros)\b').hasMatch(text);
    }
    if (category == 'Café') {
      return words.contains('cafe') && !words.contains('cafetera');
    }
    if (category == 'Manteca') {
      return words.contains('manteca') &&
          !words.contains('cacao') && !words.contains('corporal');
    }
    return words.contains(normalize(category));
  }

  static Map<String, String> extract(String category, String value) {
    final text = normalize(value);
    final result = <String, String>{};
    void match(String facet, Map<String, String> patterns) {
      for (final entry in patterns.entries) {
        if (RegExp(entry.key).hasMatch(text)) {
          result[facet] = entry.value;
          return;
        }
      }
    }

    if (category == 'Leche') {
      match('Tipo', {
        r'\bsin lactosa\b': 'Sin lactosa',
        r'\bsemidescremada\b': 'Semidescremada',
        r'\bdescremada\b': 'Descremada',
        r'\bentera\b': 'Entera',
        r'\ben polvo\b|\bpolvo\b': 'En polvo',
        r'\bchocolatada\b|\bsaborizada\b': 'Saborizada',
      });
      match('Presentación', {
        r'\bsachet\b': 'Sachet',
        r'\blarga vida\b|\btetra\b|\btetrabrik\b': 'Larga vida / Tetra',
        r'\bbotella\b': 'Botella',
        r'\bcaja\b': 'Caja',
      });
    } else if (category == 'Café') {
      match('Preparación', {
        r'\binstantaneo\b|\bsoluble\b': 'Instantáneo',
        r'\bmolido\b': 'Molido',
        r'\bgrano\b|\bgranos\b': 'En grano',
      });
      match('Proceso', {
        r'\btorrado\b': 'Torrado',
        r'\btostado\b': 'Tostado',
      });
      match('Presentación', {
        r'\bdoy\s?pack\b': 'Doypack',
        r'\bfrasco\b': 'Frasco',
        r'\bsaquitos?\b': 'Saquitos',
        r'\bcapsulas?\b': 'Cápsulas',
        r'\blata\b': 'Lata',
        r'\bpaquete\b': 'Paquete',
      });
    } else if (category == 'Manteca') {
      match('Variante', {
        r'\bsin sal\b': 'Sin sal',
        r'\bcon sal\b': 'Con sal',
      });
      match('Presentación', {
        r'\bpote\b': 'Pote',
        r'\bpan\b': 'Pan',
        r'\bpapel\b': 'Envoltorio',
        r'\bpack\b': 'Pack',
      });
    }

    final size = RegExp(r'(\d+(?:[.,]\d+)?)\s?(kg|grs?|gramos?|ml|cc|lts?|litros?)\b')
        .firstMatch(text);
    if (size != null) {
      final rawUnit = size.group(2)!;
      final unit = rawUnit.startsWith('gr') || rawUnit.startsWith('gram')
          ? 'g'
          : rawUnit == 'cc'
              ? 'ml'
              : rawUnit.startsWith('l')
                  ? 'l'
                  : rawUnit;
      result['Contenido'] = size.group(1)! + ' ' + unit;
    }
    return result;
  }

  static Map<String, List<String>> available(
    String category, Iterable<String> productNames,
  ) {
    final values = <String, Set<String>>{};
    for (final name in productNames) {
      for (final entry in extract(category, name).entries) {
        values.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
      }
    }
    return values.map((key, set) {
      final sorted = set.toList()..sort();
      return MapEntry(key, sorted);
    });
  }

  static bool matches(String category, String productName,
      Map<String, String> selected) {
    if (selected.isEmpty) return true;
    final attributes = extract(category, productName);
    return selected.entries.every(
      (entry) => attributes[entry.key] == entry.value,
    );
  }
}