import 'package:flutter/material.dart';

/// An event category used for filtering and calendar color-coding.
class EventCategory {
  final String key;
  final IconData icon;
  final Color color;
  const EventCategory(this.key, this.icon, this.color);
}

const List<EventCategory> kEventCategories = [
  EventCategory('General', Icons.event, Color(0xFF00843D)),
  EventCategory('Athletics', Icons.sports, Color(0xFF1E88E5)),
  EventCategory('Arts', Icons.palette, Color(0xFF8E24AA)),
  EventCategory('Fundraiser', Icons.savings, Color(0xFFF9A825)),
  EventCategory('Meeting', Icons.groups, Color(0xFF00897B)),
  EventCategory('Volunteer', Icons.volunteer_activism, Color(0xFF43A047)),
  EventCategory('Deadline', Icons.flag, Color(0xFFE53935)),
  EventCategory('School Holiday', Icons.beach_access, Color(0xFFFB8C00)),
  EventCategory('Half Day', Icons.schedule, Color(0xFF6D4C41)),
];

EventCategory categoryFor(String key) => kEventCategories.firstWhere(
      (c) => c.key == key,
      orElse: () => kEventCategories.first,
    );
