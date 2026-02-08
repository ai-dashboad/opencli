import 'package:flutter/material.dart';
import 'generic_domain_card.dart';
import 'music_card.dart';
import 'timer_card.dart';
import 'weather_card.dart';
import 'calculator_card.dart';
import 'calendar_card.dart';
import 'reminders_card.dart';
import 'media_creation_card.dart';

/// Registry that maps domain task types to specialized Flutter card widgets.
/// Falls back to GenericDomainCard for domains without a custom card.
class DomainCardRegistry {
  /// Check if a task type is handled by the domain card system
  static bool handles(String taskType) {
    return taskType.startsWith('music_') ||
        taskType.startsWith('timer_') ||
        taskType.startsWith('weather_') ||
        taskType.startsWith('calculator_') ||
        taskType.startsWith('calendar_') ||
        taskType.startsWith('reminders_') ||
        taskType.startsWith('notes_') ||
        taskType.startsWith('email_') ||
        taskType.startsWith('contacts_') ||
        taskType.startsWith('messages_') ||
        taskType.startsWith('translation_') ||
        taskType.startsWith('files_') ||
        taskType.startsWith('media_');
  }

  /// Build the appropriate card widget for a domain task result
  static Widget buildCard(String taskType, Map<String, dynamic> result) {
    // Music domain
    if (taskType.startsWith('music_')) {
      return MusicCard(taskType: taskType, result: result);
    }

    // Timer domain
    if (taskType.startsWith('timer_')) {
      return TimerCard(taskType: taskType, result: result);
    }

    // Weather domain
    if (taskType.startsWith('weather_')) {
      return WeatherCard(taskType: taskType, result: result);
    }

    // Calculator domain
    if (taskType.startsWith('calculator_')) {
      return CalculatorCard(taskType: taskType, result: result);
    }

    // Calendar domain
    if (taskType.startsWith('calendar_')) {
      return CalendarCard(taskType: taskType, result: result);
    }

    // Reminders domain
    if (taskType.startsWith('reminders_')) {
      return RemindersCard(taskType: taskType, result: result);
    }

    // Media Creation domain
    if (taskType.startsWith('media_')) {
      return MediaCreationCard(taskType: taskType, result: result);
    }

    // Fallback for all other domains (notes, email, contacts, messages, translation, files)
    return GenericDomainCard(taskType: taskType, result: result);
  }
}
