class ProductFacets {
  /// Categories shown by the search UI. The value is the catalog query term.
  static const categories = <String, String>{
    'Leche': 'leche',
    'Café': 'cafe',
    'Gaseosas': 'gaseosa',
    'Atún': 'atun',
    'Paté': 'pate',
    'Yogur': 'yogur',
    'Crema': 'crema',
    'Manteca': 'manteca',
    'Aceite': 'aceite',
    'Queso': 'queso',
    'Azúcar': 'azucar',
    'Arroz': 'arroz',
    'Fideos': 'fideos',
  };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');

  static bool _hasAny(Set<String> words, Iterable<String> values) =>
      values.any(words.contains);

  static bool isCategoryProduct(String category, String value) {
    final text = normalize(value);
    final words = text
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toSet();
    switch (category) {
      case 'Leche':
        if (!words.contains('leche')) return false;
        if (text.trimLeft().startsWith('leche ')) return true;
        const descriptors = {
          'entera', 'descremada', 'semidescremada', 'liviana', 'protein',
          'fortificada', 'chocolatada', 'sachet', 'lactosa', 'multidefensa',
          'larga', 'uat', 'fresca', 'polvo',
        };
        return _hasAny(words, descriptors) ||
            RegExp(r'\d+(?:[.,]\d+)?\s?(?:l|lt|litro|litros)\b')
                .hasMatch(text);
      case 'Café':
        return words.contains('cafe') && !words.contains('cafetera');
      case 'Gaseosas':
        return _hasAny(words, {
              'gaseosa', 'gaseosas', 'cola', 'soda', 'pepsi', 'sprite',
              'fanta', 'seven', '7up', 'schweppes', 'manaos', 'crush',
              'mirinda', 'cunnington',
            }) ||
            (words.contains('bebida') &&
                _hasAny(words, {'carbonatada', 'gasificada'}));
      case 'Atún':
        return _hasAny(words, {'atun', 'atunes'});
      case 'Paté':
        return _hasAny(words, {'pate', 'pates'});
      case 'Yogur':
        return _hasAny(words, {'yogur', 'yoghurt', 'yogurt'});
      case 'Crema':
        return words.contains('crema') &&
            !_hasAny(words, {'corporal', 'facial', 'manos', 'afeitar'});
      case 'Manteca':
        return words.contains('manteca') &&
            !_hasAny(words, {'cacao', 'corporal'});
      default:
        return words.contains(normalize(category));
    }
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
        r'\b(en polvo|polvo)\b': 'En polvo',
        r'\b(chocolatada|saborizada)\b': 'Saborizada',
      });
      match('Presentación', {
        r'\bsachet\b': 'Sachet',
        r'\b(larga vida|tetra|tetrabrik)\b': 'Larga vida / Tetra',
        r'\bbotella\b': 'Botella',
        r'\bcaja\b': 'Caja',
      });
    } else if (category == 'Café') {
      match('Preparación', {
        r'\b(instantaneo|soluble)\b': 'Instantáneo',
        r'\bmolido\b': 'Molido',
        r'\bgrano(s)?\b': 'En grano',
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
    } else if (category == 'Gaseosas') {
      match('Tipo', {
        r'\bsin azucar\b|\bzero\b|\bno sugar\b': 'Sin azúcar / Zero',
        r'\blight\b|\bliviana\b': 'Light',
        r'\bregular\b|\boriginal\b|\bcomun\b': 'Regular',
      });
      match('Envase', {
        r'\bretornable\b': 'Retornable',
        r'\bdescartable\b': 'Descartable',
        r'\blata\b': 'Lata',
        r'\bbotella\b': 'Botella',
      });
    } else if (category == 'Atún') {
      match('Preparación', {
        r'\bal natural\b': 'Al natural',
        r'\ben aceite\b': 'En aceite',
        r'\ben agua\b': 'En agua',
      });
      match('Presentación', {
        r'\blomitos?\b': 'Lomitos',
        r'\bdesmenuzado\b': 'Desmenuzado',
        r'\btrozos?\b': 'Trozos',
      });
    } else if (category == 'Paté') {
      match('Variedad', {
        r'\b(jamon|jamonada)\b': 'Jamón',
        r'\bcerdo\b': 'Cerdo',
        r'\bpate de higado\b': 'Hígado',
        r'\bave\b|\bpollo\b': 'Ave',
      });
    } else if (category == 'Yogur') {
      match('Tipo', {
        r'\b(griego|estilo griego)\b': 'Griego',
        r'\b bebible\b|\bbebible\b': 'Bebible',
        r'\bfirme\b': 'Firme',
        r'\bdescremado\b': 'Descremado',
        r'\bentero\b': 'Entero',
        r'\bsin lactosa\b': 'Sin lactosa',
      });
      match('Sabor', {
        r'\bfrutilla\b': 'Frutilla',
        r'\bvainilla\b': 'Vainilla',
        r'\bdurazno\b': 'Durazno',
        r'\bnatural\b': 'Natural',
      });
    } else if (category == 'Crema') {
      match('Tipo', {
        r'\b(para cocinar|cocina)\b': 'Para cocinar',
        r'\b(para batir|chantilly)\b': 'Para batir',
        r'\bliviana\b|\blight\b': 'Liviana',
        r'\bdoble\b': 'Doble',
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

    // Extract only quantities actually present in the product title/variant.
    final size = RegExp(
      r'(\d+(?:[.,]\d+)?)\s?(kg|grs?|g|gramos?|ml|cc|lts?|l|litros?)\b',
    ).firstMatch(text);
    if (size != null) {
      final rawUnit = size.group(2)!;
      final unit = rawUnit.startsWith('gr') || rawUnit.startsWith('gram')
          ? 'g'
          : rawUnit == 'cc'
              ? 'ml'
              : rawUnit.startsWith('l')
                  ? 'l'
                  : rawUnit;
      result['Contenido'] = '${size.group(1)} $unit';
    }
    return result;
  }

  static Map<String, List<String>> available(
    String category,
    Iterable<String> productNames,
  ) {
    final values = <String, Set<String>>{};
    for (final name in productNames) {
      if (!isCategoryProduct(category, name)) continue;
      for (final entry in extract(category, name).entries) {
        values.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
      }
    }
    return values.map((key, set) {
      final sorted = set.toList()..sort();
      return MapEntry(key, sorted);
    });
  }

  static String? categoryForQuery(String query) {
    final normalized = normalize(query).trim();
    for (final entry in categories.entries) {
      if (normalized == normalize(entry.value) || normalized == normalize(entry.key) || normalized.startsWith('${normalize(entry.value)} ') || normalized.startsWith('${normalize(entry.key)} ')) return entry.key;
    }
    return null;
  }

  static String? categoryForQuery(String query) {
    final normalized = normalize(query).trim();
    for (final entry in categories.entries) {
      if (normalized == normalize(entry.value) || normalized == normalize(entry.key)) return entry.key;
    }
    return null;
  }

  // Opciones de selección previas a la consulta; no implican disponibilidad en tiendas.
  static Map<String, List<String>> initialOptions(String category) {
    const options = <String, Map<String, List<String>>>{
      'Leche': {
        'Tipo': ['Entera', 'Descremada', 'Semidescremada', 'Sin lactosa', 'En polvo', 'Infantil', 'Saborizada'],
        'Presentación': ['Sachet', 'Larga vida / Tetra', 'Botella', 'Caja'],
      },
      'Café': {
        'Preparación': ['Torrado', 'Tostado', 'Instantáneo', 'Molido', 'En grano'],
        'Presentación': ['Frasco', 'Saquitos', 'Cápsulas', 'Paquete', 'Doypack'],
      },
      'Gaseosas': {
        'Tipo': ['Regular', 'Sin azúcar / Zero', 'Light'],
        'Envase': ['Botella', 'Lata', 'Retornable', 'Descartable'],
      },
      'Atún': {'Preparación': ['Al natural', 'En aceite', 'En agua'], 'Presentación': ['Lomitos', 'Desmenuzado', 'Trozos']},
      'Paté': {'Variedad': ['Jamón', 'Cerdo', 'Hígado', 'Ave']},
      'Yogur': {'Tipo': ['Griego', 'Bebible', 'Firme', 'Descremado', 'Entero', 'Sin lactosa'], 'Sabor': ['Frutilla', 'Vainilla', 'Durazno', 'Natural']},
      'Crema': {'Tipo': ['Para cocinar', 'Para batir', 'Liviana', 'Doble']},
      'Manteca': {'Variante': ['Con sal', 'Sin sal'], 'Presentación': ['Pote', 'Pan', 'Envoltorio', 'Pack']},
    };
    return options[category] ?? const {};
  }

  static bool matches(
    String category,
    String productName,
    Map<String, String> selected,
  ) {
    if (selected.isEmpty) return true;
    final attributes = extract(category, productName);
    return selected.entries.every(
      (entry) => attributes[entry.key] == entry.value,
    );
  }
}
