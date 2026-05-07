import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class StatCardData {
  final String title;
  final String value;
  final String objective;
  final int percentage;
  final Color color;
  final String? periodo;

  const StatCardData({
    required this.title,
    required this.value,
    required this.objective,
    required this.percentage,
    required this.color,
    this.periodo,
  });
}

class StatsCardsSection extends StatelessWidget {
  final List<StatCardData> cards;
  final void Function(String periodo, String title)? onEditObjective;

  const StatsCardsSection({
    super.key,
    required this.cards,
    this.onEditObjective,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: AppTheme.spacingMedium),
            StatCard(
              title: cards[i].title,
              value: cards[i].value,
              objective: cards[i].objective,
              percentage: cards[i].percentage,
              color: cards[i].color,
              periodo: cards[i].periodo,
              onEditObjective: onEditObjective,
            ),
          ],
        ],
      );
    }

    // Tablet/Desktop: 2 cards per row
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: AppTheme.spacingLarge));
      final rowCards = <Widget>[];
      rowCards.add(
        Expanded(
          child: StatCard(
            title: cards[i].title,
            value: cards[i].value,
            objective: cards[i].objective,
            percentage: cards[i].percentage,
            color: cards[i].color,
            periodo: cards[i].periodo,
            onEditObjective: onEditObjective,
          ),
        ),
      );
      if (i + 1 < cards.length) {
        rowCards.add(
          SizedBox(
            width: context.isTablet
                ? AppTheme.spacingMedium
                : AppTheme.spacingLarge,
          ),
        );
        rowCards.add(
          Expanded(
            child: StatCard(
              title: cards[i + 1].title,
              value: cards[i + 1].value,
              objective: cards[i + 1].objective,
              percentage: cards[i + 1].percentage,
              color: cards[i + 1].color,
              periodo: cards[i + 1].periodo,
              onEditObjective: onEditObjective,
            ),
          ),
        );
      }
      rows.add(Row(children: rowCards));
    }

    return Column(children: rows);
  }
}
