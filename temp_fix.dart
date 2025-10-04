            } else {
              // Si no se encuentra en opcionales, podría ser un ID directo o un ingrediente básico
              // Solo agregar si parece ser un ID válido (evitar nombres con precios)
              if (!ing.contains('(+\$') && ing.trim().isNotEmpty) {
                ingredientesIds.add(ing);
                print('   + DIRECTO: $ing');
              } else {
                print('   ⚠️ IGNORADO (formato inválido): $ing');
              }
            }