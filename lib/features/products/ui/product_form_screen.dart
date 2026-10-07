import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/choice_sheet.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/media/image_picking.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/product_form_models.dart';
import '../data/products_repository.dart';
import '../logic/product_form_providers.dart';
import '../logic/product_form_state.dart';
import '../logic/products_controller.dart';

const _kMaxWidth = 960.0;

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// null or '' = a new product.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  String get _id => widget.productId ?? '';
  bool get _isNew => _id.isEmpty;

  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _desc = TextEditingController();
  final _ingredients = TextEditingController();
  final _prep = TextEditingController();
  final _sequence = TextEditingController();

  ProductForm _form = const ProductForm();
  bool _initialized = false;
  Map<ProductField, String> _errors = {};
  bool _saving = false;
  double _progress = 0;
  int _tab = 0;
  final _keys = {for (final f in ProductField.values) f: GlobalKey()};

  @override
  void dispose() {
    for (final c in [_name, _sku, _desc, _ingredients, _prep, _sequence]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.products);

  /// Fills the form from what the server sent (once, and again after a save).
  void _init(ProductFormData d) {
    final p = d.product;
    _form = p != null
        ? ProductForm.fromProduct(p)
        : ProductForm(
      statusKey: d.statuses.isEmpty ? -1 : d.statuses.first.key, // Jetpack's default: the first status
      sku: d.skuAutoGenerate ? '${d.skuId}' : '',
    );
    _name.text = _form.name;
    _sku.text = _form.sku;
    _desc.text = _form.description;
    _ingredients.text = _form.ingredients;
    _prep.text = _form.prepTime;
    _sequence.text = _form.sequence;
    _errors = {};
    _initialized = true;
  }

  /// The form with the text fields' current text.
  ProductForm _collect() => _form.copyWith(
    name: _name.text,
    sku: _sku.text,
    description: _desc.text,
    ingredients: _ingredients.text,
    prepTime: _prep.text,
    sequence: _sequence.text,
  );

  void _clearError(ProductField f) {
    if (_errors.containsKey(f)) setState(() => _errors = {..._errors}..remove(f));
  }

  // ── pictures ──

  Future<void> _pickCover() async {
    final photo = await pickPhoto(context);
    if (photo == null || !mounted) return;
    setState(() => _form = _collect().copyWith(coverPhoto: photo));
    _clearError(ProductField.cover);
  }

  Future<void> _addImage() async {
    if (!_form.canAddImage) return;
    final photo = await pickPhoto(context);
    if (photo == null || !mounted) return;
    setState(() => _form = _collect().copyWith(newImages: [..._form.newImages, photo]));
  }

  void _removeKept(ExistingImage i) => setState(() => _form = _collect().copyWith(keptImages: [for (final k in _form.keptImages) if (k.id != i.id || k.url != i.url) k]));

  void _removeNew(int index) => setState(() => _form = _collect().copyWith(newImages: [for (var i = 0; i < _form.newImages.length; i++) if (i != index) _form.newImages[i]]));

  // ── choices ──

  Future<void> _pickCategory(ProductFormData d) async {
    final id = await showChoiceSheet(
      context,
      title: context.str('products_products_category_title'),
      items: [for (final c in d.categories) ChoiceItem('${c.key}', c.value)],
      selectedId: _form.categoryKey < 0 ? null : '${_form.categoryKey}',
    );
    if (id == null || !mounted) return;
    final key = int.tryParse(id) ?? -1;
    if (key == _form.categoryKey) return;
    setState(() => _form = _collect().copyWith(categoryKey: key, subCategoryKey: -1)); // a new category has its own sub-categories
    _clearError(ProductField.category);
    _clearError(ProductField.subCategory);
  }

  Future<void> _pickSub(List<FormOption> subs) async {
    final id = await showChoiceSheet(
      context,
      title: context.str('products_products_sub_category_title'),
      items: [for (final s in subs) ChoiceItem('${s.key}', s.value)],
      selectedId: _form.subCategoryKey < 0 ? null : '${_form.subCategoryKey}',
    );
    if (id == null || !mounted) return;
    setState(() => _form = _collect().copyWith(subCategoryKey: int.tryParse(id) ?? -1));
    _clearError(ProductField.subCategory);
  }

  // ── save ──

  bool _subRequired(ProductFormData d, ProductForm f) {
    if (d.subCategoryOptional || f.categoryKey < 0) return false;
    final subs = ref.read(subCategoriesProvider(f.categoryKey));
    // a category that has no sub-categories cannot require one
    return !(subs.hasValue && (subs.value ?? const []).isEmpty);
  }

  void _scrollToFirstError(Map<ProductField, String> errors) {
    for (final f in ProductField.values) {
      if (!errors.containsKey(f)) continue;
      final ctx = _keys[f]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      return;
    }
  }

  Future<void> _save(ProductFormData d, bool isFood) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final f = _collect();
    final errors = validateProduct(f, isFood: isFood, skuAutoGenerate: d.skuAutoGenerate, subCategoryRequired: _subRequired(d, f));
    setState(() {
      _form = f;
      _errors = errors;
    });
    if (errors.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstError(errors));
      return;
    }

    setState(() {
      _saving = true;
      _progress = 0;
    });
    try {
      final r = await ref.read(productsRepositoryProvider).saveBasics(_id, f, onProgress: (v) {
        if (mounted) setState(() => _progress = v);
      });
      if (!mounted) return;
      ref.invalidate(productsProvider); // the list shows the new data
      if (r.message.isNotEmpty) showAppSnack(context, r.message);
      if (_isNew && r.id.isNotEmpty) {
        context.go(Routes.productEdit(r.id)); // the same screen, now with the other tabs unlocked
        return;
      }
      ref.invalidate(productFormDataProvider(_id));
      setState(() {
        _saving = false;
        _initialized = false; // fill the form again from the saved product
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final isFood = ref.watch(appPrefsProvider).isFood;
    final async = ref.watch(productFormDataProvider(_id));
    final data = async.value;
    if (data != null && !_initialized && !async.isLoading) _init(data);

    final title = context.str(_isNew ? 'products_addproductscreen_title_add' : 'products_addproductscreen_title_edit');
    final ready = data != null && _initialized;

    final Widget content;
    if (ready) {
      content = _tab == 0 ? _basicInfo(data, isFood, compact) : _Soon(titleKey: _tab == 1 ? 'products_productdetail_variants_title' : 'products_stockmanagement_update_title');
    } else if (async.hasError && data == null) {
      content = _ErrorCard(message: errorText(async.error!, ref.read(stringsProvider)), onRetry: () => ref.invalidate(productFormDataProvider(_id)));
    } else {
      content = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 170, radius: 16), SizedBox(height: 12), SkeletonBox(height: 56, radius: 12), SizedBox(height: 12), SkeletonBox(height: 56, radius: 12)]));
    }

    final saveButton = FilledButton(
      onPressed: (ready && !_saving && _tab == 0) ? () => _save(data, isFood) : null,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      child: _saving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
        const SizedBox(width: 10),
        Text(context.str('common_allscreen_saving')),
      ])
          : Text(context.str('products_addproductscreen_saveProduct')),
    );

    final tabs = _FormTabs(selected: _tab, locked: _isNew, onSelect: (i) => setState(() => _tab = i));
    final progress = _saving ? LinearProgressIndicator(value: _progress > 0 && _progress < 1 ? _progress : null, minHeight: 3) : const SizedBox(height: 3);
    final pad = compact ? 16.0 : 0.0;

    final body = Expanded(
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
        children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _kMaxWidth), child: content))],
      ),
    );

    if (compact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(children: [
                  IconButton(onPressed: _back, tooltip: MaterialLocalizations.of(context).backButtonTooltip, icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))),
                ]),
              ),
              tabs,
              progress,
              body,
              Container(
                decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
                child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: SizedBox(width: double.infinity, child: saveButton))),
              ),
            ],
          ),
        ),
      );
    }

    return AdaptivePage(
      title: title,
      fallbackRoute: Routes.products,
      actions: [saveButton],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tabs, progress, body]),
    );
  }

  // ── the Basic info tab ──

  Widget _basicInfo(ProductFormData d, bool isFood, bool compact) {
    final tk = context.tk;
    final f = _form;
    String err(ProductField k) => _errors[k] == null ? '' : context.str(_errors[k]!);
    String? errOrNull(ProductField k) => _errors[k] == null ? null : context.str(_errors[k]!);

    String optionName(List<FormOption> list, int key) {
      for (final o in list) {
        if (o.key == key) return o.value;
      }
      return '';
    }

    // sub-categories of the chosen category
    final subsAsync = f.categoryKey >= 0 ? ref.watch(subCategoriesProvider(f.categoryKey)) : null;
    final subs = subsAsync?.value ?? const <FormOption>[];
    final String? subHelper = f.categoryKey < 0
        ? null
        : subsAsync!.isLoading
        ? context.str('products_addproductscreen_loadingSubcategories')
        : subsAsync.hasError
        ? context.str('common_allscreen_something_went_wrong')
        : subs.isEmpty
        ? context.str('products_addproductscreen_noSubcategoriesAvailable')
        : null;

    final cover = _CoverPicker(key: _keys[ProductField.cover], photo: f.coverPhoto, url: f.coverUrl, error: errOrNull(ProductField.cover), onTap: _pickCover);

    final slots = <Widget>[
      for (final i in f.keptImages) _ImageSlot.network(i.url, onRemove: () => _removeKept(i)),
      for (var n = 0; n < f.newImages.length; n++) _ImageSlot.memory(f.newImages[n].bytes, onRemove: () => _removeNew(n)),
    ];
    final images = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_addproductscreen_images_title')),
        Row(
          children: [
            for (var i = 0; i < kMaxProductImages; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: i < slots.length ? slots[i] : (i == slots.length ? _ImageSlot.add(onTap: _addImage) : const _ImageSlot.empty()),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    Widget field(ProductField k, String labelKey, Widget input) => Column(
      key: _keys[k],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(context.str(labelKey)), input],
    );

    InputDecoration deco(String hintKey, ProductField? k) => InputDecoration(hintText: context.str(hintKey), errorText: k == null ? null : errOrNull(k));

    final skuField = field(
      ProductField.sku,
      d.skuAutoGenerate ? 'products_addproductscreen_skuAutoGenerated' : 'products_addproductscreen_skuNumber',
      TextField(
        controller: _sku,
        readOnly: d.skuAutoGenerate,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _clearError(ProductField.sku),
        decoration: InputDecoration(
          hintText: d.skuAutoGenerate ? context.str('products_addproductscreen_willBeGeneratedAutomatically') : null,
          errorText: errOrNull(ProductField.sku),
          suffixIcon: d.skuAutoGenerate ? Icon(Icons.auto_awesome_rounded, size: 18, color: tk.text3) : null,
        ),
      ),
    );

    final nameField = field(
      ProductField.name,
      'products_products_name_title',
      TextField(controller: _name, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.sentences, onChanged: (_) => _clearError(ProductField.name), decoration: deco('products_products_name_placeholder', ProductField.name)),
    );

    final categoryField = field(
      ProductField.category,
      'products_products_category_title',
      _SelectField(
        value: optionName(d.categories, f.categoryKey),
        placeholder: context.str('products_products_category_placeholder'),
        error: errOrNull(ProductField.category),
        onTap: () => _pickCategory(d),
      ),
    );

    final subField = field(
      ProductField.subCategory,
      'products_products_sub_category_title',
      _SelectField(
        value: optionName(subs, f.subCategoryKey),
        placeholder: context.str('products_products_sub_category_placeholder'),
        error: errOrNull(ProductField.subCategory),
        helper: subHelper,
        loading: subsAsync?.isLoading ?? false,
        enabled: f.categoryKey >= 0 && subs.isNotEmpty,
        onTap: () => _pickSub(subs),
      ),
    );

    final descField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_products_description_title')),
        TextField(controller: _desc, minLines: 3, maxLines: 6, textCapitalization: TextCapitalization.sentences, decoration: deco('products_products_description_placeholder', null)),
      ],
    );

    final ingredientsField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_products_ingredients_title')),
        TextField(controller: _ingredients, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: deco('products_products_ingredients_placeholder', null)),
      ],
    );

    final foodType = d.foodTypes.isEmpty
        ? null
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_addproductscreen_select_food_type_title')),
        _ChipSelect(options: d.foodTypes, selectedKey: f.foodTypeKey, onSelect: (k) => setState(() => _form = _collect().copyWith(foodTypeKey: k))),
      ],
    );

    final prepField = field(
      ProductField.prepTime,
      'products_products_preparation_time_title',
      TextField(
        controller: _prep,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        textInputAction: TextInputAction.next,
        onChanged: (_) => _clearError(ProductField.prepTime),
        decoration: deco('products_products_preparation_time_placeholder', ProductField.prepTime),
      ),
    );

    final seqField = field(
      ProductField.sequence,
      'products_products_sequence_title',
      TextField(
        controller: _sequence,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
        onChanged: (_) => _clearError(ProductField.sequence),
        decoration: deco('products_products_sequence_placeholder', ProductField.sequence),
      ),
    );

    final inventory = Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: tk.text2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.str('products_addproductscreen_inventory_title'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                Text(context.str(f.manageInventory ? 'products_addproductscreen_inventory_Disbalemessage' : 'products_addproductscreen_inventory_message'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
              ],
            ),
          ),
          Switch(value: f.manageInventory, onChanged: (v) => setState(() => _form = _collect().copyWith(manageInventory: v))),
        ],
      ),
    );

    final status = d.statuses.isEmpty
        ? null
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_addproductscreen_select_status_title')),
        _ChipSelect(options: d.statuses, selectedKey: f.statusKey, onSelect: (k) => setState(() => _form = _collect().copyWith(statusKey: k))),
      ],
    );

    // (widget, takes the full width on wide screens)
    final cells = <(Widget, bool)>[
      (nameField, false),
      (skuField, false),
      (categoryField, false),
      (subField, false),
      (descField, true),
      if (isFood) (ingredientsField, true),
      if (isFood && foodType != null) (foodType, true),
      if (isFood) (prepField, false),
      (seqField, false),
      (inventory, true),
      if (status != null) (status, true),
    ];

    return LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 640;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cover), const SizedBox(width: 16), Expanded(child: images)]) else ...[cover, const SizedBox(height: 16), images],
          const SizedBox(height: 22),
          _SectionTitle(context.str('products_addproductscreen_productDetails')),
          _FormGrid(two: two, cells: cells),
        ],
      );
    });
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

class _FormTabs extends StatelessWidget {
  const _FormTabs({required this.selected, required this.locked, required this.onSelect});

  final int selected;

  /// A new product: only the first tab until it is saved.
  final bool locked;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    final labels = [
      context.str('products_addproductscreen_productDetails'),
      context.str('products_productdetail_variants_title'),
      context.str('products_stockmanagement_update_title'),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: (locked && i > 0) ? null : () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == selected ? primary : Colors.transparent, width: 2.5))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (locked && i > 0) ...[Icon(Icons.lock_outline_rounded, size: 14, color: tk.text3), const SizedBox(width: 4)],
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500, color: (locked && i > 0) ? tk.text3 : (i == selected ? primary : tk.text2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormGrid extends StatelessWidget {
  const _FormGrid({required this.two, required this.cells});

  final bool two;
  final List<(Widget, bool)> cells;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    const gap = 16.0;
    final half = (box.maxWidth - gap) / 2;
    return Wrap(
      spacing: gap,
      runSpacing: 16,
      children: [for (final (w, full) in cells) SizedBox(width: (two && !full) ? half : box.maxWidth, child: w)],
    );
  });
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.tk.text1)),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tk.text2)),
  );
}

class _SelectField extends StatelessWidget {
  const _SelectField({required this.value, required this.placeholder, required this.onTap, this.error, this.helper, this.loading = false, this.enabled = true});

  final String value;
  final String placeholder;
  final VoidCallback onTap;
  final String? error;
  final String? helper;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: enabled ? tk.surface : tk.sunken,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: hasError ? tk.danger : tk.border, width: hasError ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value.isEmpty ? placeholder : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: value.isEmpty ? tk.text3 : tk.text1))),
                if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.keyboard_arrow_down_rounded, color: tk.text3),
              ],
            ),
          ),
        ),
        if (hasError || helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error ?? helper!, style: TextStyle(fontSize: 12.5, color: hasError ? tk.danger : tk.text3)),
          ),
      ],
    );
  }
}

class _ChipSelect extends StatelessWidget {
  const _ChipSelect({required this.options, required this.selectedKey, required this.onSelect});

  final List<FormOption> options;
  final int selectedKey;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => onSelect(o.key),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: o.key == selectedKey ? context.primary : tk.surface,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: o.key == selectedKey ? context.primary : tk.border),
              ),
              child: Text(o.value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: o.key == selectedKey ? Colors.white : tk.text2)),
            ),
          ),
      ],
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({super.key, required this.photo, required this.url, required this.error, required this.onTap});

  final PickedPhoto? photo;
  final String url;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasError = error != null;
    final has = photo != null || url.isNotEmpty;
    final Widget image = photo != null
        ? Image.memory(photo!.bytes, fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 900, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.str('products_addproductscreen_coverImage')),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onTap,
          child: Container(
            height: 170,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: hasError ? tk.dangerBg : tk.sunken,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: hasError ? tk.danger : tk.border, width: hasError ? 1.5 : 1),
            ),
            child: has
                ? Stack(fit: StackFit.expand, children: [
              image,
              PositionedDirectional(
                end: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                ),
              ),
            ])
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 38, color: hasError ? tk.danger : tk.text3),
                const SizedBox(height: 8),
                Text(context.str('products_addproductscreen_tapToUploadCoverImage'), style: TextStyle(fontWeight: FontWeight.w600, color: hasError ? tk.danger : tk.text2)),
                const SizedBox(height: 2),
                Text(context.str('products_addproductscreen_jpgPngSupported'), style: TextStyle(fontSize: 12, color: tk.text3)),
              ],
            ),
          ),
        ),
        if (hasError) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(error!, style: TextStyle(fontSize: 12.5, color: tk.danger))),
      ],
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot._({this.image, this.onTap, this.onRemove});

  const _ImageSlot.empty() : this._();
  _ImageSlot.add({required VoidCallback onTap}) : this._(onTap: onTap);
  _ImageSlot.network(String url, {required VoidCallback onRemove}) : this._(image: _net(url), onRemove: onRemove);
  _ImageSlot.memory(Uint8List bytes, {required VoidCallback onRemove}) : this._(image: Image.memory(bytes, fit: BoxFit.cover), onRemove: onRemove);

  final Widget? image;
  final VoidCallback? onTap; // the "+" slot
  final VoidCallback? onRemove;

  static Widget _net(String url) => CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 300, errorWidget: (_, _, _) => const ColoredBox(color: Colors.black12));

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image!,
            PositionedDirectional(
              top: 4,
              end: 4,
              child: InkWell(
                onTap: onRemove,
                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: onTap == null ? tk.border.withValues(alpha: 0.5) : context.primary.withValues(alpha: 0.5))),
        child: onTap == null ? null : Icon(Icons.add_rounded, color: context.primary),
      ),
    );
  }
}

/// The Variants and Stock tabs arrive in 16B.
class _Soon extends StatelessWidget {
  const _Soon({required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(children: [
      Icon(Icons.construction_rounded, size: 48, color: context.tk.text3),
      const SizedBox(height: 12),
      Text(context.str(titleKey), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.tk.text1)),
    ]),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 44, color: context.tk.text3),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.tk.text2)),
        const SizedBox(height: 14),
        FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
      ]),
    ),
  );
}