import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/workstations/presentation/providers/workstation_providers.dart';
import 'package:order_app/features/workstations/presentation/viewmodel/workstations_view_model.dart';

import '../../../support/fakes.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeWorkstationRepository repo;

  ProviderContainer start() {
    final container = ProviderContainer(
      overrides: [workstationRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.listen(workstationsViewModelProvider, (_, _) {});
    return container;
  }

  setUp(() {
    repo = FakeWorkstationRepository()
      ..items = [aWorkstation(id: 1, code: 'WS-01'), aWorkstation(id: 2, code: 'WS-02')];
  });

  test('loads the list on start', () async {
    final container = start();
    expect(container.read(workstationsViewModelProvider).isLoading, isTrue);
    await settle();

    final state = container.read(workstationsViewModelProvider);
    expect(state.isLoading, isFalse);
    expect(state.items.map((w) => w.code), ['WS-01', 'WS-02']);
  });

  test('a failed load carries the reason', () async {
    repo.listFailure = const NetworkFailure();
    final container = start();
    await settle();

    final state = container.read(workstationsViewModelProvider);
    expect(state.items, isEmpty);
    expect(state.error, const NetworkFailure().message);
  });

  test('a new workstation is added in code order', () async {
    final container = start();
    await settle();

    final problem = await container
        .read(workstationsViewModelProvider.notifier)
        .create(name: 'Early', code: 'WS-00', location: 'Building B');

    expect(problem, isNull);
    expect(container.read(workstationsViewModelProvider).items.map((w) => w.code), ['WS-00', 'WS-01', 'WS-02']);
  });

  test('a rejected create hands back the reason and changes nothing', () async {
    repo.createFailure = const ValidationFailure('The code has already been taken.');
    final container = start();
    await settle();

    final problem = await container
        .read(workstationsViewModelProvider.notifier)
        .create(name: 'Dup', code: 'WS-01', location: 'x');

    expect(problem, 'The code has already been taken.');
    expect(container.read(workstationsViewModelProvider).items, hasLength(2));
  });

  test('switching a workstation off updates just that one', () async {
    final container = start();
    await settle();

    await container
        .read(workstationsViewModelProvider.notifier)
        .setActive(aWorkstation(id: 2, code: 'WS-02'), false);

    final items = container.read(workstationsViewModelProvider).items;
    expect(items.firstWhere((w) => w.id == 2).isActive, isFalse);
    expect(items.firstWhere((w) => w.id == 1).isActive, isTrue);
  });

  test('a failed switch leaves the list alone and raises a notice', () async {
    repo.setActiveFailure = const NetworkFailure();
    final container = start();
    await settle();

    await container.read(workstationsViewModelProvider.notifier).setActive(aWorkstation(id: 2), false);

    final state = container.read(workstationsViewModelProvider);
    expect(state.items.firstWhere((w) => w.id == 2).isActive, isTrue);
    expect(state.notice, const NetworkFailure().message);

    container.read(workstationsViewModelProvider.notifier).consumeNotice();
    expect(container.read(workstationsViewModelProvider).notice, isNull);
  });
}
