import 'package:flutter/widgets.dart';

import 'schedule_controller.dart';

/// Makes the controller available to the widget tree and rebuilds dependents on change.
class ScheduleScope extends InheritedNotifier<ScheduleController> {
  const ScheduleScope({super.key, required ScheduleController controller, required super.child})
    : super(notifier: controller);

  static ScheduleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScheduleScope>()!.notifier!;
}
