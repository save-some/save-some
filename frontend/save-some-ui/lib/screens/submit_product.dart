import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/app_text_field.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// "Submit a Product" — the design's voting frame.
///
/// Users propose a product URL, pick which store it's from and which category it
/// belongs to, and submit it for community voting.
///
/// The form is complete and validated, but submission is deliberately stubbed:
/// the schema has no submissions or votes table, and inventing one without
/// agreeing its shape would be worse than a clear TODO. Everything else here —
/// validation, store list, category list — runs against the real API.
class SubmitProductScreen extends StatefulWidget {
  final String userId;

  const SubmitProductScreen({super.key, required this.userId});

  @override
  State<SubmitProductScreen> createState() => _SubmitProductScreenState();
}

class _SubmitProductScreenState extends State<SubmitProductScreen> {
  final _services = AppServices.instance;
  final _urlController = TextEditingController();

  late Future<_SubmitFormData> _formData;

  String? _selectedRetailerId;
  String? _selectedCategoryId;
  bool _storesExpanded = true;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _formData = _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<_SubmitFormData> _load() async {
    final retailers = await _services.retailers.fetchAll();
    final categories = await _services.categories.fetchAll();
    return _SubmitFormData(retailers: retailers, categories: categories);
  }

  String get _url => _urlController.text.trim();

  String? get _urlError {
    if (!_attempted) return null;
    if (_url.isEmpty) return 'Paste a link to the product';
    final parsed = Uri.tryParse(_url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return 'That doesn\'t look like a valid link';
    }
    return null;
  }

  String? get _storeError =>
      _attempted && _selectedRetailerId == null ? 'Pick a store' : null;

  String? get _categoryError =>
      _attempted && _selectedCategoryId == null ? 'Pick a category' : null;

  bool get _isValid =>
      _urlError == null &&
      _url.isNotEmpty &&
      _selectedRetailerId != null &&
      _selectedCategoryId != null;

  void _submit() {
    setState(() => _attempted = true);
    if (!_isValid) return;

    // The payload the backend will need, assembled and ready.
    final payload = {
      'user_id': widget.userId,
      'product_url': _url,
      'retailer_id': _selectedRetailerId,
      'category_id': _selectedCategoryId,
    };

    // TODO: POST this to a submissions endpoint once the table exists. Needs
    // something like product_submissions(id, user_id, product_url, retailer_id,
    // category_id, status, submitted_at) plus a votes table, neither of which is
    // in the schema today.
    debugPrint('save-some: product submission ready but not sent: $payload');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Submissions aren\'t accepted by the backend yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a Product')),
      body: SafeArea(
        child: FutureBuilder<_SubmitFormData>(
          future: _formData,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                message: 'Couldn\'t load stores and categories.',
                error: snapshot.error,
                onRetry: () => setState(() => _formData = _load()),
              );
            }
            if (!snapshot.hasData) return const AppLoading();
            final data = snapshot.data!;

            return ListView(
              padding: AppSpacing.pageAll,
              children: [
                const SectionHeader('Product Link'),
                AppTextField(
                  controller: _urlController,
                  hint: 'Paste URL here',
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                  isIdentifier: true,
                  errorText: _urlError,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Stores'),
                _SelectorField(
                  label: _labelFor(data.retailers, _selectedRetailerId) ??
                      'Select a Store',
                  expanded: _storesExpanded,
                  errorText: _storeError,
                  onTap: () =>
                      setState(() => _storesExpanded = !_storesExpanded),
                ),
                if (_storesExpanded) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    child: Column(
                      children: [
                        for (final retailer in data.retailers)
                          _StoreRow(
                            name: retailer.name,
                            selected: _selectedRetailerId == retailer.id,
                            onTap: () => setState(() {
                              _selectedRetailerId = retailer.id;
                              _storesExpanded = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Category'),
                _CategoryDropdown(
                  categories: data.categories,
                  selectedId: _selectedCategoryId,
                  errorText: _categoryError,
                  onChanged: (id) => setState(() => _selectedCategoryId = id),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Submit for Vote',
                  icon: Icons.how_to_vote_outlined,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            );
          },
        ),
      ),
    );
  }

  static String? _labelFor(List<Retailer> retailers, String? id) {
    if (id == null) return null;
    for (final retailer in retailers) {
      if (retailer.id == id) return retailer.name;
    }
    return null;
  }
}

/// The collapsed "Select a Store" row that expands the list beneath it.
class _SelectorField extends StatelessWidget {
  final String label;
  final bool expanded;
  final String? errorText;
  final VoidCallback onTap;

  const _SelectorField({
    required this.label,
    required this.expanded,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surface,
          borderRadius: AppRadius.smAll,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smAll,
            side: BorderSide(
              color: errorText == null ? scheme.outlineVariant : scheme.error,
            ),
          ),
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              left: AppSpacing.md,
            ),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}

class _StoreRow extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _StoreRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: AvatarBadge(source: name, size: 32),
      title: Text(name),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.chevron_right,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'e.g. Clothing, Electronics, etc',
        errorText: errorText,
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _SubmitFormData {
  final List<Retailer> retailers;
  final List<Category> categories;

  const _SubmitFormData({required this.retailers, required this.categories});
}
