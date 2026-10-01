// OWNER: recipes UI agent.
// Recipes tab: a "Recommended for you" row based on today's remaining
// macros, plus one section per meal category with every recipe in the
// catalog. Tapping a card opens its ingredients, steps and full macros.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../domain/models.dart';
import 'recipes_providers.dart';

const _categories = [Meal.breakfast, Meal.lunch, Meal.dinner, Meal.snack];

String _categoryLabel(Meal m) => switch (m) {
  Meal.breakfast => 'Breakfast',
  Meal.lunch => 'Lunch',
  Meal.dinner => 'Dinner',
  Meal.snack => 'Snacks',
};

/// Recipes tab: recommendations plus a browsable catalog by meal category.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayKey = dayKeyOf(ref.watch(clockProvider)());

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _RecommendedSection(dayKey: todayKey),
          for (final category in _categories)
            _CategorySection(category: category),
        ],
      ),
    );
  }
}

/// "Recommended for you" horizontal row from [recommendedRecipesProvider].
class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection({required this.dayKey});
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommended = ref.watch(recommendedRecipesProvider(dayKey));

    Widget body;
    if (recommended.hasError) {
      body = _ErrorText(
        recommended.error!,
        onRetry: () => ref.invalidate(recommendedRecipesProvider(dayKey)),
      );
    } else if (!recommended.hasValue) {
      body = const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (recommended.value!.isEmpty) {
      body = SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Set up your profile to get recommendations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      body = SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: recommended.value!.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => SizedBox(
            width: 220,
            child: _RecipeCard(recipe: recommended.value![i]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommended for you', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

/// One meal-category section: a header plus a grid of recipe cards.
class _CategorySection extends ConsumerWidget {
  const _CategorySection({required this.category});
  final Meal category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesByCategoryProvider(category));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_categoryLabel(category), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (recipes.isEmpty)
            Text(
              'No recipes yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recipes.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 170,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, i) => _RecipeCard(recipe: recipes[i]),
            ),
        ],
      ),
    );
  }
}

/// A recipe card: name, kcal and macro chips. Tap opens the detail sheet.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macros = recipe.perServing;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecipeDetail(context, recipe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recipe.name,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${macros.kcal.round()} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _MacroChip(label: 'P ${macros.proteinG.round()}g'),
                  _MacroChip(label: 'F ${macros.fatG.round()}g'),
                  _MacroChip(label: 'C ${macros.carbsG.round()}g'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Opens a bottom sheet with the full recipe: macros, ingredients, steps.
void _showRecipeDetail(BuildContext context, Recipe recipe) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RecipeDetailSheet(recipe: recipe),
  );
}

class _RecipeDetailSheet extends StatelessWidget {
  const _RecipeDetailSheet({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final macros = recipe.perServing;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(recipe.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${_categoryLabel(recipe.category)} · '
            '${recipe.servings} serving${recipe.servings == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroChip(label: '${macros.kcal.round()} kcal'),
              _MacroChip(label: 'Protein ${macros.proteinG.round()}g'),
              _MacroChip(label: 'Fat ${macros.fatG.round()}g'),
              _MacroChip(label: 'Carbs ${macros.carbsG.round()}g'),
            ],
          ),
          const SizedBox(height: 20),
          Text('Ingredients', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ingredient in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ingredient)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text('Steps', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (i, step) in recipe.steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Short friendly error with Try again.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error, {required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    debugPrint('Recipes failed to load: $error');
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load recommendations.",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
