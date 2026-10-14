import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_courier.dart';
import '../../core/models/tajgo_order.dart';
import '../../core/models/app_user.dart';
import '../../core/models/courier_application.dart';
import '../../core/services/courier_repository.dart';
import '../../core/services/external_navigator_service.dart';
import '../../core/services/pricing.dart';
import '../map/services/tajgo_location_service.dart';
import '../../shared/widgets/tajgo_order_card.dart';
import '../../shared/widgets/tajgo_order_progress.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_state_view.dart';
import '../../core/services/user_error_message.dart';
import '../../core/services/authoritative_command_service.dart';
import '../../core/design/tajgo_money.dart';
import '../../shared/widgets/tajgo_status_pill.dart';
import 'courier_order_screen.dart';
import 'courier_application_status_screen.dart';
import 'courier_onboarding_screen.dart';
import '../account/account_profile_screen.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _profileEnsured = false;
  bool _profileReady = false;
  String? _profileError;
  Stream<TajGoCourier?>? _courierStream;
  int _statsRevision = 0;
  bool _broadcasting = false;
  bool _locationErrorShown = false;
  bool _locationBlocked = false;
  bool _locationStarting = false;
  bool _lastOnline = false;
  TajGoLocationException? _locationIssue;
  String? _locationWriteError;
  StreamSubscription<Position>? _positionSubscription;

  String get _uid => TajGoScope.of(context).authService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _lastOnline &&
        _positionSubscription == null) {
      _retryLocation();
    } else if (state != AppLifecycleState.resumed) {
      final subscription = _positionSubscription;
      _positionSubscription = null;
      unawaited(subscription?.cancel());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TajGoScope.of(context).notificationService.navigationReady();
    });
    if (_profileEnsured) {
      return;
    }
    _profileEnsured = true;
    Future<void>.microtask(_ensureCourierProfile);
  }

  Future<void> _ensureCourierProfile() async {
    String? uid;
    bool approved = false;
    if (mounted) setState(() => _profileError = null);
    try {
      final scope = TajGoScope.of(context);
      uid = _uid;
      final user = await scope.userRepository.getUser(uid);
      if (!mounted || scope.authService.currentUser?.uid != uid) return;
      if (user?.courierApproved != true) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => CourierApplicationStatusScreen(
                status: user?.courierStatus ?? CourierStatus.none,
              ),
            ),
          );
        }
        return;
      }
      if (!user!.courierOnboardingCompleted) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const CourierOnboardingScreen(),
            ),
          );
        }
        return;
      }
      approved = true;
      await scope.courierRepository.ensureCourierProfile(
        uid: uid,
        phoneNumber: user.phoneNumber,
        displayName: user.displayName,
        city: user.city,
      );
      if (mounted && scope.authService.currentUser?.uid == uid) {
        setState(() {
          _courierStream = scope.courierRepository.courierStream(user.uid);
          _profileReady = true;
        });
      }
    } catch (error) {
      final code = error is FirebaseException
          ? error.code
          : error is TajGoCommandException
          ? error.code
          : null;
      final transient =
          error is TimeoutException ||
          const {
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          }.contains(code);
      if (approved && transient && uid != null && mounted) {
        try {
          final scope = TajGoScope.of(context);
          final existing = await scope.courierRepository.getCourier(uid);
          if (mounted &&
              existing != null &&
              scope.authService.currentUser?.uid == uid) {
            setState(() {
              _courierStream = scope.courierRepository.courierStream(uid!);
              _profileReady = false;
              _profileError = userErrorMessage(error);
            });
            return;
          }
        } catch (_) {
          /* Show setup recovery if cached data is unavailable. */
        }
      }
      if (mounted) setState(() => _profileError = userErrorMessage(error));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on TajGoLocationException catch (error) {
      if (mounted) {
        setState(() => _locationIssue = error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TajGoLocationException
                  ? error.message
                  : userErrorMessage(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setOnline(bool online) => _run(() async {
    final scope = TajGoScope.of(context);
    final user = await scope.userRepository.getUser(_uid);
    if (user?.courierApproved != true) {
      throw StateError('Курьерский режим недоступен до одобрения заявки.');
    }
    if (online) {
      final initial = await scope.locationService.determineCurrentPosition();
      await scope.courierRepository.updateLocation(
        uid: _uid,
        latitude: initial.latitude,
        longitude: initial.longitude,
        heading: initial.heading,
        speed: initial.speed,
        accuracy: initial.accuracy,
        force: true,
      );
    }
    await scope.courierRepository.setOnline(
      uid: _uid,
      online: online,
      name: user?.name ?? 'Курьер',
      city: user?.city ?? 'Худжанд',
      phoneNumber: user?.phoneNumber,
    );
    if (mounted) {
      setState(() {
        _locationIssue = null;
        _locationWriteError = null;
        _locationBlocked = false;
      });
    }
  });

  void _openOrder(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourierOrderScreen(orderId: orderId)),
    );
  }

  Future<void> _submitOffer(TajGoOrder order, {required bool custom}) async {
    final clientPrice = order.clientPrice ?? order.price;
    if (custom && !order.priceNegotiable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для этого заказа цена фиксирована.')),
      );
      return;
    }
    num proposedPrice = clientPrice;
    if (custom) {
      final controller = TextEditingController(
        text: (clientPrice.toInt() + 1).toString(),
      );
      final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Предложить свою цену'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Цена, сомони',
              helperText: 'Цена клиента: ${TajGoMoney.format(clientPrice)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                int.tryParse(controller.text.trim()),
              ),
              child: const Text('Отправить'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (value == null) return;
      if (value <= clientPrice) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Своя цена должна быть выше цены клиента.'),
            ),
          );
        }
        return;
      }
      proposedPrice = value;
    }
    await _run(() async {
      await TajGoScope.of(context).courierOfferRepository.submitCourierOffer(
        orderId: order.id,
        courierId: _uid,
        proposedPrice: proposedPrice,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Предложение отправлено клиенту.')),
        );
      }
    });
  }

  Future<void> _resetTestOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сбросить тестовый заказ?'),
        content: const Text(
          'Заказ вернётся в ленту со статусом waiting. Курьер останется на линии.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(() async {
      await TajGoScope.of(
        context,
      ).courierRepository.resetActiveOrderForTesting(courierId: _uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тестовый заказ возвращён в ленту.')),
        );
      }
    });
  }

  Future<void> _syncLocationBroadcast(bool online) async {
    if (!online) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _locationBlocked = false;
      _locationStarting = false;
      if (mounted && _broadcasting) {
        setState(() => _broadcasting = false);
      }
      return;
    }
    if (_positionSubscription != null ||
        _broadcasting ||
        _locationBlocked ||
        _locationStarting) {
      return;
    }
    _locationStarting = true;
    try {
      final scope = TajGoScope.of(context);
      final initial = await scope.locationService.determineCurrentPosition();
      await scope.courierRepository.updateLocation(
        uid: _uid,
        latitude: initial.latitude,
        longitude: initial.longitude,
        heading: initial.heading,
        speed: initial.speed,
        accuracy: initial.accuracy,
      );
      _positionSubscription = scope.locationService.positionStream().listen(
        (position) => unawaited(_publishPosition(position)),
        onError: (Object error) async {
          await _positionSubscription?.cancel();
          _positionSubscription = null;
          _locationBlocked = true;
          if (mounted) {
            setState(() {
              _broadcasting = false;
              if (error is TajGoLocationException) {
                _locationIssue = error;
              } else {
                _locationWriteError = userErrorMessage(error);
              }
            });
            if (!_locationErrorShown) {
              _locationErrorShown = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    error is TajGoLocationException
                        ? error.message
                        : userErrorMessage(error),
                  ),
                ),
              );
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _broadcasting = true;
          _locationStarting = false;
          _locationErrorShown = false;
          _locationIssue = null;
          _locationWriteError = null;
        });
      }
    } catch (error) {
      _locationBlocked = true;
      _locationStarting = false;
      if (mounted) {
        setState(() {
          if (error is TajGoLocationException) {
            _locationIssue = error;
          } else {
            _locationWriteError = userErrorMessage(error);
          }
        });
      }
      if (mounted && !_locationErrorShown) {
        _locationErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TajGoLocationException
                  ? error.message
                  : userErrorMessage(error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _publishPosition(Position position) async {
    try {
      await TajGoScope.of(context).courierRepository.updateLocation(
        uid: _uid,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
      );
      if (mounted && _locationWriteError != null) {
        setState(() => _locationWriteError = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _locationWriteError = userErrorMessage(error));
      }
    }
  }

  void _retryLocation() {
    if (!_lastOnline || _locationStarting) {
      return;
    }
    setState(() {
      _locationBlocked = false;
      _locationIssue = null;
      _locationWriteError = null;
    });
    unawaited(_syncLocationBroadcast(true));
  }

  Future<void> _openLocationSettings() async {
    final issue = _locationIssue;
    if (issue == null) {
      _retryLocation();
      return;
    }
    await TajGoScope.of(context).locationService.openSettingsFor(issue.issue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).courierRepository;
    if (_courierStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TajGo Курьер')),
        body: _profileError == null
            ? const Center(child: CircularProgressIndicator())
            : TajGoStateView(
                icon: Icons.person_outline_rounded,
                title: 'Не удалось подготовить профиль',
                message: _profileError!,
                onRetry: _ensureCourierProfile,
                actionLabel: 'Повторить',
              ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: StreamBuilder<TajGoCourier?>(
          stream: _courierStream,
          builder: (context, courierSnapshot) {
            if (courierSnapshot.hasError) {
              return TajGoStateView(
                icon: Icons.cloud_off_rounded,
                title: 'Не удалось загрузить данные курьера',
                message: userErrorMessage(courierSnapshot.error),
                actionLabel: 'Повторить',
                onRetry: () => setState(
                  () => _courierStream = repository.courierStream(_uid),
                ),
              );
            }
            final courier = courierSnapshot.data;
            final online = courier?.online ?? false;
            _lastOnline = online && _profileReady;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _syncLocationBroadcast(online && _profileReady);
              }
            });
            return StreamBuilder<TajGoOrder?>(
              stream: courier?.activeOrderId == null
                  ? Stream<TajGoOrder?>.value(null)
                  : repository.orderStream(courier!.activeOrderId!),
              builder: (context, activeSnapshot) {
                if (activeSnapshot.hasError) {
                  return TajGoStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Не удалось загрузить текущий заказ',
                    message: userErrorMessage(activeSnapshot.error),
                    onRetry: () => setState(() {}),
                    actionLabel: 'Повторить',
                  );
                }
                final activeOrder = activeSnapshot.data;
                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _CourierHeader(
                            online: online,
                            broadcasting: _broadcasting,
                            busy: _busy || !_profileReady,
                            onToggle: () => _setOnline(!online),
                            onProfileReturned: () {
                              if (mounted) setState(() => _statsRevision++);
                            },
                          ),
                          if (_profileError != null)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Профиль не обновлён',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(_profileError!),
                                  TextButton(
                                    onPressed: _ensureCourierProfile,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          if (_locationIssue != null ||
                              _locationWriteError != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: _LocationIssueCard(
                                message:
                                    _locationIssue?.message ??
                                    _locationWriteError!,
                                settingsRequired:
                                    _locationIssue?.requiresSettings ?? false,
                                onRetry: online
                                    ? _retryLocation
                                    : () => _setOnline(true),
                                onSettings: _openLocationSettings,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: _PilotStats(
                              key: ValueKey(_statsRevision),
                              courier: courier,
                            ),
                          ),
                          TabBar(
                            isScrollable:
                                MediaQuery.textScalerOf(context).scale(14) > 20,
                            tabs: const [
                              Tab(text: 'Рядом'),
                              Tab(text: 'Дальше'),
                              Tab(text: 'Мой заказ'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      if (!online)
                        const _EmptyFeed(
                          icon: Icons.delivery_dining_rounded,
                          text: 'Выйдите на линию, чтобы видеть заказы',
                        )
                      else
                        _PilotOrdersFeed(
                          courier: courier,
                          repository: repository,
                          courierId: _uid,
                          nearby: true,
                          busy: _busy || !_profileReady,
                          onAcceptPrice: (order) =>
                              _submitOffer(order, custom: false),
                          onCustomPrice: (order) =>
                              _submitOffer(order, custom: true),
                        ),
                      if (!online)
                        const _EmptyFeed(
                          icon: Icons.location_on_outlined,
                          text: 'Выйдите на линию, чтобы обновить расстояния',
                        )
                      else
                        _PilotOrdersFeed(
                          courier: courier,
                          repository: repository,
                          courierId: _uid,
                          nearby: false,
                          busy: _busy || !_profileReady,
                          onAcceptPrice: (order) =>
                              _submitOffer(order, custom: false),
                          onCustomPrice: (order) =>
                              _submitOffer(order, custom: true),
                        ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_locationIssue != null ||
                              _locationWriteError != null)
                            const SizedBox.shrink(),
                          if (activeOrder != null) ...[
                            TajGoOrderCard(
                              order: activeOrder,
                              backgroundColor: TajGoColors.mint,
                              onTap: () => _openOrder(activeOrder.id),
                              actions: Column(
                                children: [
                                  TajGoOrderProgress(
                                    currentStep: switch (activeOrder.status) {
                                      OrderStatus.accepted
                                          when activeOrder.arrivedAtPickupAt !=
                                              null =>
                                        1,
                                      OrderStatus.accepted => 0,
                                      OrderStatus.pickedUp => 3,
                                      OrderStatus.delivered ||
                                      OrderStatus.completed ||
                                      OrderStatus.disputed => 4,
                                      _ => 0,
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    switch (activeOrder.status) {
                                      OrderStatus.accepted
                                          when activeOrder.arrivedAtPickupAt !=
                                              null =>
                                        'Курьер на месте',
                                      OrderStatus.accepted =>
                                        'Едем к точке забора',
                                      OrderStatus.pickedUp =>
                                        'Доставляем клиенту',
                                      OrderStatus.delivered =>
                                        'Ждём подтверждения клиента',
                                      OrderStatus.disputed =>
                                        'Доставка на проверке',
                                      OrderStatus.completed => 'Заказ завершён',
                                      _ => 'Активный заказ',
                                    },
                                    style: const TextStyle(
                                      color: TajGoColors.darkGreen,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (kDebugMode)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _busy ? null : _resetTestOrder,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text(
                                    'Тест · Сбросить тестовый заказ',
                                  ),
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Завершите текущий заказ, чтобы принять следующий',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: TajGoColors.muted),
                                ),
                              ),
                            ),
                          ] else ...[
                            const _EmptyFeed(
                              icon: Icons.inbox_outlined,
                              text: 'Активного заказа пока нет',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PilotStats extends StatefulWidget {
  const _PilotStats({super.key, required this.courier});
  final TajGoCourier? courier;
  @override
  State<_PilotStats> createState() => _PilotStatsState();
}

class _PilotStatsState extends State<_PilotStats> {
  Future<NavigatorPreference>? _navigator;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator ??= TajGoScope.of(context).externalNavigatorService.load();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final courier = widget.courier;
      final columns = MediaQuery.textScalerOf(context).scale(11) > 15 ? 2 : 4;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      final items = <Widget>[
        _MiniStat(
          label: 'GPS',
          value: courier?.location == null
              ? 'выключен'
              : (courier?.locationAccuracy ?? 999) <= 50
              ? 'точный'
              : 'слабый',
        ),
        _MiniStat(
          label: 'Транспорт',
          value: CourierTransport.label(
            CourierTransport.normalize(courier?.transport),
          ),
        ),
        FutureBuilder<NavigatorPreference>(
          future: _navigator,
          builder: (context, snapshot) => _MiniStat(
            label: 'Навигатор',
            value: switch (snapshot.data?.navigator) {
              ExternalNavigator.yandex => 'Яндекс',
              ExternalNavigator.google => 'Google',
              ExternalNavigator.twoGis => '2ГИС',
              ExternalNavigator.system => 'Телефон',
              _ => 'TajGo',
            },
          ),
        ),
        _MiniStat(
          label: 'Сегодня',
          value:
              '${courier?.ordersToday ?? 0} · ${TajGoMoney.format(courier?.earningsToday ?? 0)}',
        ),
      ];
      return Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final item in items) SizedBox(width: width, child: item),
        ],
      );
    },
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: TajGoColors.muted, fontSize: 10),
        ),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ],
    ),
  );
}

class _PilotOrdersFeed extends StatelessWidget {
  const _PilotOrdersFeed({
    required this.courier,
    required this.repository,
    required this.courierId,
    required this.nearby,
    required this.busy,
    required this.onAcceptPrice,
    required this.onCustomPrice,
  });

  final TajGoCourier? courier;
  final CourierRepository repository;
  final String courierId;
  final bool nearby;
  final bool busy;
  final ValueChanged<TajGoOrder> onAcceptPrice;
  final ValueChanged<TajGoOrder> onCustomPrice;

  double? _distance(TajGoOrder order) {
    final location = courier?.location;
    final pickup = order.fromLocation;
    if (location == null || pickup == null) return null;
    return haversineDistanceKm(
          LatLng(location.latitude, location.longitude),
          LatLng(pickup.latitude, pickup.longitude),
        ) *
        1000;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TajGoOrder>>(
    stream: repository.waitingOrdersStream(),
    builder: (context, snapshot) {
      final orders =
          (snapshot.data ?? const <TajGoOrder>[])
              .where(
                (order) =>
                    order.customerId != courierId &&
                    !order.declinedBy.contains(courierId) &&
                    (_distance(order) == null
                        ? !nearby
                        : nearby
                        ? _distance(order)! < 1000
                        : _distance(order)! >= 1000),
              )
              .toList()
            ..sort((a, b) {
              final distance = (_distance(a) ?? double.infinity).compareTo(
                _distance(b) ?? double.infinity,
              );
              if (distance != 0) return distance;
              return (a.createdAt ?? DateTime(2100)).compareTo(
                b.createdAt ?? DateTime(2100),
              );
            });
      if (orders.isEmpty) {
        return _EmptyFeed(
          icon: nearby ? Icons.inbox_outlined : Icons.location_on_outlined,
          text: nearby
              ? 'Рядом пока нет доступных заказов'
              : 'Дальних заказов пока нет',
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final meters = _distance(order);
          return TajGoOrderCard(
            order: order,
            actions: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  meters == null
                      ? 'Обновляем ваше местоположение…'
                      : '${meters.round()} м до точки A',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (!nearby)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Заказ пока далеко. Приблизьтесь к точке забора на расстояние меньше 1 км.',
                      style: TextStyle(color: TajGoColors.muted),
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (order.priceNegotiable) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => onCustomPrice(order),
                            child: const Text('Предложить свою'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => onAcceptPrice(order),
                          child: Text(
                            'Принять ${TajGoMoney.format(order.clientPrice ?? order.price)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _LocationIssueCard extends StatelessWidget {
  const _LocationIssueCard({
    required this.message,
    required this.settingsRequired,
    required this.onRetry,
    required this.onSettings,
  });

  final String message;
  final bool settingsRequired;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TajGoColors.warning),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_off_rounded, color: TajGoColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Геолокация недоступна',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(message, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              TextButton(
                onPressed: settingsRequired ? onSettings : onRetry,
                child: Text(
                  settingsRequired ? 'Открыть настройки' : 'Повторить',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CourierHeader extends StatelessWidget {
  const _CourierHeader({
    required this.online,
    required this.broadcasting,
    required this.busy,
    required this.onToggle,
    required this.onProfileReturned,
  });

  final bool online;
  final bool broadcasting;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onProfileReturned;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      12,
      MediaQuery.paddingOf(context).top + 6,
      18,
      24,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [TajGoColors.deepGreen, TajGoColors.darkGreen],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (Navigator.canPop(context))
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Назад',
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            const Expanded(
              child: Text(
                'TajGo Курьер · Худжанд',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Профиль',
              color: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CourierProfileScreen(),
                ),
              ).then((_) => onProfileReturned()),
              icon: const Icon(Icons.account_circle_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TajGoStatusPill(online: online),
        const SizedBox(height: 12),
        Text(
          online ? 'Вы на линии' : 'Готовы выйти на линию?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (broadcasting)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '📡 координаты передаются',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: SizedBox(
            width: double.infinity,
            child: online
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                    onPressed: busy ? null : onToggle,
                    child: const Text('Уйти с линии'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: TajGoColors.darkGreen,
                    ),
                    onPressed: busy ? null : onToggle,
                    child: const Text('Выйти на линию'),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      TajGoStateView(icon: icon, title: text, message: '');
}
