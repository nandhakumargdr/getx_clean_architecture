import 'dart:async';

import 'package:int_quest/utils/service/log_service.dart';

import 'base_observer.dart';

abstract class UseCaseO<T> extends _UseCase<void, T> {
  @override
  Future<Stream<T>> _buildUseCaseStream(void _) async {
    final controller = StreamController<T>();
    try {
      final value = await build();
      controller.add(value);
      controller.close();
    } catch (e) {
      L.error(e);
      controller.addError(e);
    }
    return controller.stream;
  }

  Future<void> execute({Observer<T>? observer}) async {
    return _execute(observer: observer);
  }

  Future<T> build();
}

abstract class UseCaseIO<Input, T> extends _UseCase<Input, T> {
  @override
  Future<Stream<T>> _buildUseCaseStream(Input? input) async {
    final controller = StreamController<T>();
    try {
      final value = await build(input!);
      controller.add(value);
      controller.close();
    } catch (e) {
      L.error(e);
      controller.addError(e);
    }
    return controller.stream;
  }

  Future<void> execute({Observer<T>? observer, required Input input}) async {
    return _execute(observer: observer, input: input);
  }

  Future<T> build(Input input);
}

abstract class _UseCase<Input, T> {
  late _CompositeSubscription _disposables;

  _UseCase() {
    _disposables = _CompositeSubscription();
  }

  Future<Stream<T>> _buildUseCaseStream(Input? input);

  Future<void> _execute({Observer<T>? observer, Input? input}) async {
    observer?.onSubscribe();
    final StreamSubscription subscription =
        (await _buildUseCaseStream(input)).listen(
      (data) {
        observer?.onSuccess(data);
      },
      onDone: observer?.onCompleted(),
      onError: (e) {
        observer?.onError(e);
      },
    );
    _addSubscription(subscription);
  }

  void dispose() {
    if (!_disposables.isDisposed) {
      _disposables.dispose();
    }
  }

  void _addSubscription(StreamSubscription subscription) {
    if (_disposables.isDisposed) {
      _disposables = _CompositeSubscription();
    }
    _disposables.add(subscription);
  }
}

class _CompositeSubscription {
  bool _isDisposed = false;

  final List<StreamSubscription<dynamic>> _subscriptionsList = [];

  /// Checks if this composite is disposed. If it is, the composite can't be used again
  /// and will throw an error if you try to add more subscriptions to it.
  bool get isDisposed => _isDisposed;

  /// Returns the total amount of currently added [StreamSubscription]s
  int get length => _subscriptionsList.length;

  /// Checks if there currently are no [StreamSubscription]s added
  bool get isEmpty => _subscriptionsList.isEmpty;

  /// Checks if there currently are [StreamSubscription]s added
  bool get isNotEmpty => _subscriptionsList.isNotEmpty;

  /// Whether all managed [StreamSubscription]s are currently paused.
  bool get allPaused => _subscriptionsList.isNotEmpty
      ? _subscriptionsList.every((it) => it.isPaused)
      : false;

  /// Adds new subscription to this composite.
  ///
  /// Throws an exception if this composite was disposed
  StreamSubscription<T> add<T>(StreamSubscription<T> subscription) {
    if (isDisposed) {
      throw ('This composite was disposed, try to use new instance instead');
    }
    if (_subscriptionsList.isNotEmpty) {
      remove(_subscriptionsList.last);
    }
    _subscriptionsList.add(subscription);
    return subscription;
  }

  /// Cancels subscription and removes it from this composite.
  void remove(StreamSubscription<dynamic> subscription) {
    subscription.cancel();
    _subscriptionsList.remove(subscription);
  }

  /// Cancels all subscriptions added to this composite. Clears subscriptions collection.
  ///
  /// This composite can be reused after calling this method.
  void clear() {
    _subscriptionsList.forEach((it) => it.cancel());
    _subscriptionsList.clear();
  }

  /// Cancels all subscriptions added to this composite. Disposes this.
  ///
  /// This composite can't be reused after calling this method.
  void dispose() {
    clear();
    _isDisposed = true;
  }

  /// Pauses all subscriptions added to this composite.
  void pauseAll([Future? resumeSignal]) =>
      _subscriptionsList.forEach((it) => it.pause(resumeSignal));

  /// Resumes all subscriptions added to this composite.
  void resumeAll() => _subscriptionsList.forEach((it) => it.resume());
}

/// Extends the [StreamSubscription] class with the ability to be added to [_CompositeSubscription] container.
extension AddToCompositeSubscriptionExtension<T> on StreamSubscription<T> {
  /// Adds this subscription to composite container for subscriptions.
  void addTo(_CompositeSubscription _compositeSubscription) =>
      _compositeSubscription.add(this);
}
