import 'package:home_widget/home_widget.dart';
import '../models/queue_model.dart';

/// Service for updating the Android/iOS home screen widget.
class HomeWidgetService {
  static const String _appGroupId = 'group.com.example.queueless';
  static const String _widgetName = 'QueueWidget';

  static Future<void> updateWidget(List<QueueEntryModel> activeQueues) async {
    try {
      if (activeQueues.isEmpty) {
        await HomeWidget.saveWidgetData<String>('widget_business', 'No active queue');
        await HomeWidget.saveWidgetData<String>('widget_position', '');
        await HomeWidget.saveWidgetData<String>('widget_wait', '');
      } else {
        // Show the first (most recent) active queue
        final entry = activeQueues.first;
        final peopleAhead = entry.peopleAhead ?? (entry.position > 0 ? entry.position - 1 : 0);
        final waitTime = entry.waitTimeEstimate;

        await HomeWidget.saveWidgetData<String>(
          'widget_business',
          entry.businessName ?? 'Business',
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_position',
          peopleAhead == 0
              ? '🎉 Your turn is next!'
              : '$peopleAhead people ahead of you',
        );
        await HomeWidget.saveWidgetData<String>(
          'widget_wait',
          'Est. wait: $waitTime',
        );
      }
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
        iOSName: _widgetName,
        qualifiedAndroidName: 'es.antonborri.home_widget.HomeWidgetBackgroundReceiver',
      );
    } catch (_) {
      // Widget not supported on this platform — silently ignore
    }
  }

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (_) {}
  }
}
