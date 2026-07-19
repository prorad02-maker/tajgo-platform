import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/models/marketplace_product.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_marketplace_import_screen.dart';
import 'widgets/admin_access_gate.dart';

class AdminMarketplaceScreen extends StatelessWidget {
  const AdminMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Партнёры и товары'),
          actions: [
            IconButton(
              tooltip: 'Загрузить примеры в Firestore',
              onPressed: () => _publishSamples(context),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            IconButton(
              tooltip: 'Импорт JSON',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AdminMarketplaceImportScreen(),
                ),
              ),
              icon: const Icon(Icons.data_object_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Партнёры'),
              Tab(text: 'Товары'),
            ],
          ),
        ),
        body: const TabBarView(children: [_PartnersTab(), _ProductsTab()]),
      ),
    ),
  );
}

class _PartnersTab extends StatelessWidget {
  const _PartnersTab();

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).marketplaceRepository;
    return StreamBuilder<List<MarketplacePartner>>(
      stream: repository.allPartnersStream(),
      builder: (context, snapshot) => _AdminListShell(
        loading: snapshot.connectionState == ConnectionState.waiting,
        error: snapshot.hasError,
        empty: (snapshot.data ?? const []).isEmpty,
        addLabel: 'Добавить партнёра',
        onAdd: () => _editPartner(context),
        children: [
          for (final partner in snapshot.data ?? const <MarketplacePartner>[])
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: partner.isActive
                      ? TajGoColors.mint
                      : TajGoColors.soonBg,
                  child: Icon(
                    Icons.storefront_rounded,
                    color: partner.isActive
                        ? TajGoColors.darkGreen
                        : TajGoColors.muted,
                  ),
                ),
                title: Text(
                  partner.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${marketplaceCategoryLabel(partner.category)} · '
                  '${partner.isOpen ? 'открыт' : 'закрыт'} · '
                  '${partner.deliveryFee} TJS доставка',
                ),
                trailing: IconButton(
                  tooltip: 'Изменить',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _editPartner(context, partner),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AdminPartnerAssortmentScreen(partner: partner),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPartnerAssortmentScreen extends StatelessWidget {
  const AdminPartnerAssortmentScreen({super.key, required this.partner});

  final MarketplacePartner partner;

  @override
  Widget build(BuildContext context) => AdminAccessGate(
    child: Scaffold(
      appBar: AppBar(
        title: Text(partner.name),
        actions: [
          IconButton(
            tooltip: 'Изменить карточку',
            onPressed: () => _editPartner(context, partner),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<MarketplaceProduct>>(
        stream: TajGoScope.of(
          context,
        ).marketplaceRepository.productsStream(partner.id, includeHidden: true),
        builder: (context, snapshot) {
          final products = snapshot.data ?? const <MarketplaceProduct>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                color: TajGoColors.mint,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marketplaceCategoryLabel(partner.category),
                        style: const TextStyle(
                          color: TajGoColors.darkGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(partner.address),
                      const SizedBox(height: 4),
                      Text(
                        '${partner.isActive ? 'Показывается клиентам' : 'Скрыт'} · '
                        '${partner.isOpen ? 'открыт' : 'закрыт'} · '
                        '${products.length} позиций',
                        style: const TextStyle(color: TajGoColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Ассортимент',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                const _Message(
                  icon: Icons.cloud_off_rounded,
                  text: 'Не удалось загрузить ассортимент.',
                )
              else if (products.isEmpty)
                const _Message(
                  icon: Icons.inventory_2_outlined,
                  text: 'У этого партнёра пока нет товаров.',
                )
              else
                for (final product in products)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: product.isAvailable && !product.hidden
                            ? TajGoColors.mint
                            : TajGoColors.soonBg,
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: TajGoColors.darkGreen,
                        ),
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${product.price} TJS / '
                        '${marketplaceUnitLabel(product.unit)}'
                        '${product.hidden ? ' · скрыт' : ''}'
                        '${!product.isAvailable ? ' · нет в наличии' : ''}',
                      ),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: () => _editProduct(
                        context,
                        product: product,
                        initialPartner: partner,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(context, initialPartner: partner),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить товар'),
      ),
    ),
  );
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).marketplaceRepository;
    return StreamBuilder<List<MarketplaceProduct>>(
      stream: repository.allProductsStream(),
      builder: (context, snapshot) => _AdminListShell(
        loading: snapshot.connectionState == ConnectionState.waiting,
        error: snapshot.hasError,
        empty: (snapshot.data ?? const []).isEmpty,
        addLabel: 'Добавить товар',
        onAdd: () => _editProduct(context),
        children: [
          for (final product in snapshot.data ?? const <MarketplaceProduct>[])
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.isAvailable && !product.hidden
                      ? TajGoColors.mint
                      : TajGoColors.soonBg,
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: TajGoColors.darkGreen,
                  ),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${product.price} TJS / ${marketplaceUnitLabel(product.unit)}'
                  '${product.hidden ? ' · скрыт' : ''}'
                  '${!product.isAvailable ? ' · нет в наличии' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Изменить',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _editProduct(context, product: product),
                ),
                onTap: () => _editProduct(context, product: product),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminListShell extends StatelessWidget {
  const _AdminListShell({
    required this.loading,
    required this.error,
    required this.empty,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final bool loading;
  final bool error;
  final bool empty;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(addLabel),
      ),
      const SizedBox(height: 12),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error)
        const _Message(
          icon: Icons.lock_outline_rounded,
          text: 'Нет доступа к данным. Проверьте admin-role и Firestore Rules.',
        ),
      if (!loading && !error && empty)
        const _Message(
          icon: Icons.inventory_2_outlined,
          text: 'Данных пока нет. Добавьте первую позицию.',
        ),
      ...children,
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 48, color: TajGoColors.muted),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

Future<void> _editPartner(
  BuildContext context, [
  MarketplacePartner? partner,
]) async {
  final scope = TajGoScope.of(context);
  final value = await showDialog<MarketplacePartner>(
    context: context,
    builder: (_) => _PartnerEditorDialog(partner: partner),
  );
  if (value == null || !context.mounted) return;
  if (partner?.isActive == true && !value.isActive) {
    final confirmed = await _confirmDanger(
      context,
      'Скрыть партнёра?',
      'Клиенты не смогут оформить новый заказ у этого партнёра.',
    );
    if (!confirmed || !context.mounted) return;
  }
  try {
    await scope.marketplaceRepository.savePartner(
      partner: value,
      adminId: scope.authService.currentUser!.uid,
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<void> _editProduct(
  BuildContext context, {
  MarketplaceProduct? product,
  MarketplacePartner? initialPartner,
}) async {
  final scope = TajGoScope.of(context);
  late final List<MarketplacePartner> partners;
  try {
    partners = await scope.marketplaceRepository.allPartnersStream().first;
  } catch (error) {
    if (context.mounted) _showError(context, error);
    return;
  }
  if (!context.mounted) return;
  if (partners.isEmpty) {
    _showError(context, 'Сначала добавьте партнёра.');
    return;
  }
  final value = await showDialog<MarketplaceProduct>(
    context: context,
    builder: (_) => _ProductEditorDialog(
      product: product,
      partners: partners,
      initialPartnerId: initialPartner?.id,
    ),
  );
  if (value == null || !context.mounted) return;
  if (product != null && product.partnerId != value.partnerId) {
    final confirmed = await _confirmDanger(
      context,
      'Перенести товар к другому партнёру?',
      'Товар сразу исчезнет из старого ассортимента и появится в новом.',
    );
    if (!confirmed || !context.mounted) return;
  }
  if (product != null &&
      ((!product.hidden && value.hidden) ||
          (product.isAvailable && !value.isAvailable))) {
    final confirmed = await _confirmDanger(
      context,
      value.hidden ? 'Скрыть товар?' : 'Убрать товар из наличия?',
      value.hidden
          ? 'Товар исчезнет из каталога клиента, но останется в истории заказов.'
          : 'Клиенты увидят товар как недоступный и не смогут добавить его в корзину.',
    );
    if (!confirmed || !context.mounted) return;
  }
  try {
    await scope.marketplaceRepository.saveProduct(
      product: value,
      adminId: scope.authService.currentUser!.uid,
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

void _showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );

Future<void> _publishSamples(BuildContext context) async {
  final confirmed = await _confirmDanger(
    context,
    'Загрузить примеры в Firestore?',
    'Будут созданы или обновлены 6 демонстрационных заведений и их '
        'ассортимент. Повторный запуск безопасно обновляет те же записи.',
  );
  if (!confirmed || !context.mounted) return;
  final scope = TajGoScope.of(context);
  try {
    await scope.marketplaceRepository.publishSampleCatalog(
      adminId: scope.authService.currentUser!.uid,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Примерный каталог записан в Firestore.')),
      );
    }
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<bool> _confirmDanger(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    ) ??
    false;

class _PartnerEditorDialog extends StatefulWidget {
  const _PartnerEditorDialog({this.partner});
  final MarketplacePartner? partner;

  @override
  State<_PartnerEditorDialog> createState() => _PartnerEditorDialogState();
}

class _PartnerEditorDialogState extends State<_PartnerEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _minimum;
  late final TextEditingController _fee;
  late final TextEditingController _preparation;
  late final TextEditingController _rating;
  late final TextEditingController _sortOrder;
  late final TextEditingController _hours;
  late String _category;
  late bool _open;
  late bool _active;
  late GeoPoint _location;

  @override
  void initState() {
    super.initState();
    final item = widget.partner;
    _name = TextEditingController(text: item?.name);
    _address = TextEditingController(text: item?.address);
    _description = TextEditingController(text: item?.description);
    _image = TextEditingController(text: item?.imageUrl);
    _minimum = TextEditingController(text: '${item?.minimumOrder ?? 0}');
    _fee = TextEditingController(text: '${item?.deliveryFee ?? 10}');
    _preparation = TextEditingController(
      text: '${item?.preparationMinutes ?? 20}',
    );
    _rating = TextEditingController(text: '${item?.rating ?? 5}');
    _sortOrder = TextEditingController(text: '${item?.sortOrder ?? 0}');
    _hours = TextEditingController(text: item?.workingHours ?? '09:00–22:00');
    _category = item?.category ?? 'food';
    _open = item?.isOpen ?? true;
    _active = item?.isActive ?? true;
    _location = item?.location ?? const GeoPoint(40.2833, 69.6222);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _description,
      _image,
      _minimum,
      _fee,
      _preparation,
      _rating,
      _sortOrder,
      _hours,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.partner == null ? 'Новый партнёр' : 'Изменить партнёра'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _requiredField(_name, 'Название'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  for (final value in marketplaceCategories)
                    DropdownMenuItem(
                      value: value,
                      child: Text(marketplaceCategoryLabel(value)),
                    ),
                ],
                onChanged: (value) => _category = value ?? _category,
              ),
              const SizedBox(height: 10),
              _requiredField(_address, 'Адрес'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _httpsUrlField(_image, 'URL изображения'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(_minimum, 'Мин. заказ')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_fee, 'Доставка')),
                ],
              ),
              const SizedBox(height: 10),
              _numberField(
                _preparation,
                'Приготовление, минут',
                max: 240,
                integer: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(_rating, 'Рейтинг 0–5', max: 5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      _sortOrder,
                      'Порядок показа',
                      max: 10000,
                      integer: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _hours,
                decoration: const InputDecoration(labelText: 'Часы работы'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_rounded,
                  color: TajGoColors.green,
                ),
                title: const Text('Точка партнёра на карте'),
                subtitle: Text(
                  '${_location.latitude.toStringAsFixed(5)}, '
                  '${_location.longitude.toStringAsFixed(5)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _chooseLocation,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Открыт сейчас'),
                value: _open,
                onChanged: (value) => setState(() => _open = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Показывать клиентам'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Сохранить')),
    ],
  );

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final old = widget.partner;
    Navigator.pop(
      context,
      MarketplacePartner(
        id:
            old?.id ??
            TajGoScope.of(context).marketplaceRepository.newPartnerId(),
        name: _name.text,
        category: _category,
        description: _description.text,
        imageUrl: _image.text,
        address: _address.text,
        location: _location,
        minimumOrder: num.parse(_minimum.text.replaceAll(',', '.')),
        deliveryFee: num.parse(_fee.text.replaceAll(',', '.')),
        rating: num.parse(_rating.text.replaceAll(',', '.')).toDouble(),
        preparationMinutes: num.parse(
          _preparation.text.replaceAll(',', '.'),
        ).toInt(),
        sortOrder: num.parse(_sortOrder.text).toInt(),
        workingHours: _hours.text,
        isOpen: _open,
        isActive: _active,
        isTest: old?.isTest ?? false,
      ),
    );
  }

  Future<void> _chooseLocation() async {
    final selected = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminPartnerLocationScreen(initial: _location),
      ),
    );
    if (selected != null && mounted) setState(() => _location = selected);
  }
}

class _ProductEditorDialog extends StatefulWidget {
  const _ProductEditorDialog({
    required this.partners,
    this.product,
    this.initialPartnerId,
  });
  final List<MarketplacePartner> partners;
  final MarketplaceProduct? product;
  final String? initialPartnerId;

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late final TextEditingController _oldPrice;
  late final TextEditingController _popularity;
  late final TextEditingController _sortOrder;
  late String _partnerId;
  late String _unit;
  late bool _available;
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    final item = widget.product;
    _name = TextEditingController(text: item?.name);
    _description = TextEditingController(text: item?.description);
    _image = TextEditingController(text: item?.imageUrl);
    _price = TextEditingController(text: '${item?.price ?? 0}');
    _oldPrice = TextEditingController(text: '${item?.oldPrice ?? ''}');
    _popularity = TextEditingController(text: '${item?.popularity ?? 0}');
    _sortOrder = TextEditingController(text: '${item?.sortOrder ?? 0}');
    _partnerId =
        item?.partnerId ?? widget.initialPartnerId ?? widget.partners.first.id;
    _unit = item?.unit ?? 'item';
    _available = item?.isAvailable ?? true;
    _hidden = item?.hidden ?? false;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _image,
      _price,
      _oldPrice,
      _popularity,
      _sortOrder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Новый товар' : 'Изменить товар'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _partnerId,
                decoration: const InputDecoration(labelText: 'Партнёр'),
                items: [
                  for (final partner in widget.partners)
                    DropdownMenuItem(
                      value: partner.id,
                      child: Text(partner.name),
                    ),
                ],
                onChanged: (value) => _partnerId = value ?? _partnerId,
              ),
              const SizedBox(height: 10),
              _requiredField(_name, 'Название'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _httpsUrlField(_image, 'URL изображения'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _price,
                      'Цена, TJS',
                      min: 0.01,
                      max: 100000,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Единица'),
                      items: [
                        for (final value in marketplaceProductUnits)
                          DropdownMenuItem(
                            value: value,
                            child: Text(marketplaceUnitLabel(value)),
                          ),
                      ],
                      onChanged: (value) => _unit = value ?? _unit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _optionalNumberField(
                      _oldPrice,
                      'Старая цена',
                      minProvider: () =>
                          num.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
                      max: 100000,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _numberField(
                      _popularity,
                      'Популярность',
                      max: 1000000,
                      integer: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _numberField(
                _sortOrder,
                'Порядок показа',
                max: 10000,
                integer: true,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('В наличии'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Скрыть товар'),
                value: _hidden,
                onChanged: (value) => setState(() => _hidden = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Сохранить')),
    ],
  );

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final old = widget.product;
    Navigator.pop(
      context,
      MarketplaceProduct(
        id:
            old?.id ??
            TajGoScope.of(context).marketplaceRepository.newProductId(),
        partnerId: _partnerId,
        name: _name.text,
        description: _description.text,
        imageUrl: _image.text,
        price: num.parse(_price.text.replaceAll(',', '.')),
        oldPrice: _oldPrice.text.trim().isEmpty
            ? null
            : num.parse(_oldPrice.text.replaceAll(',', '.')),
        unit: _unit,
        isAvailable: _available,
        hidden: _hidden,
        popularity: num.parse(_popularity.text).toInt(),
        sortOrder: num.parse(_sortOrder.text).toInt(),
        isTest: old?.isTest ?? false,
      ),
    );
  }
}

TextFormField _requiredField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Заполните поле' : null,
    );

TextFormField _numberField(
  TextEditingController controller,
  String label, {
  num min = 0,
  num? max,
  bool integer = false,
}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label),
  validator: (value) {
    final number = num.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null ||
        !number.isFinite ||
        number < min ||
        (max != null && number > max)) {
      return max == null ? 'Минимум $min' : 'От $min до $max';
    }
    if (integer && number != number.roundToDouble()) {
      return 'Только целое число';
    }
    return null;
  },
);

TextFormField _optionalNumberField(
  TextEditingController controller,
  String label, {
  num Function()? minProvider,
  num? max,
}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label),
  validator: (value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = num.tryParse(value.replaceAll(',', '.'));
    final min = minProvider?.call() ?? 0;
    if (number == null || !number.isFinite || number < min) {
      return 'Не меньше $min';
    }
    if (max != null && number > max) return 'Не больше $max';
    return null;
  },
);

TextFormField _httpsUrlField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (raw.isEmpty) return null;
        final uri = Uri.tryParse(raw);
        return uri == null || uri.scheme != 'https' || uri.host.isEmpty
            ? 'Нужен HTTPS URL'
            : null;
      },
    );

class _AdminPartnerLocationScreen extends StatefulWidget {
  const _AdminPartnerLocationScreen({required this.initial});
  final GeoPoint initial;

  @override
  State<_AdminPartnerLocationScreen> createState() =>
      _AdminPartnerLocationScreenState();
}

class _AdminPartnerLocationScreenState
    extends State<_AdminPartnerLocationScreen> {
  final _map = MapController();
  bool _locating = false;

  LatLng get _initial =>
      LatLng(widget.initial.latitude, widget.initial.longitude);

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final position = await TajGoScope.of(
        context,
      ).locationService.determineCurrentPosition();
      if (mounted) {
        _map.move(LatLng(position.latitude, position.longitude), 16);
      }
    } catch (error) {
      if (mounted) _showError(context, 'Не удалось определить GPS.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Точка партнёра')),
    body: Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _initial,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tj.tajgo.app',
              maxZoom: 19,
            ),
            RichAttributionWidget(
              attributions: const [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_pin,
                size: 52,
                color: TajGoColors.green,
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 86,
          child: FloatingActionButton.small(
            heroTag: 'adminPartnerLocate',
            onPressed: _locating ? null : _locate,
            child: _locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(12),
      child: FilledButton(
        onPressed: () {
          final point = _map.camera.center;
          Navigator.pop(context, GeoPoint(point.latitude, point.longitude));
        },
        child: const Text('Сохранить точку'),
      ),
    ),
  );
}
