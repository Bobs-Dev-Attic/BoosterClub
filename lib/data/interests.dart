import 'package:flutter/material.dart';

/// A selectable sub-category within an interest group.
class InterestSub {
  final String key;
  final String label;
  const InterestSub(this.key, this.label);
}

/// A top-level interest group. When [subs] is empty the group itself is the
/// selectable interest (its [key]); otherwise the sub-categories are selectable
/// as `<group.key>.<sub.key>`.
class InterestGroup {
  final String key;
  final String label;
  final IconData icon;
  final List<InterestSub> subs;
  const InterestGroup(this.key, this.label, this.icon, this.subs);

  bool get hasSubs => subs.isNotEmpty;
  String subKey(InterestSub s) => '$key.${s.key}';
  List<String> get allSubKeys => subs.map(subKey).toList();
}

/// The interest taxonomy for email/notification preferences.
const List<InterestGroup> kInterestGroups = [
  InterestGroup('sports', 'Sports', Icons.sports_football, [
    InterestSub('football', 'Football'),
    InterestSub('basketball', 'Basketball'),
    InterestSub('baseball', 'Baseball'),
    InterestSub('softball', 'Softball'),
    InterestSub('soccer', 'Soccer'),
    InterestSub('golf', 'Golf'),
    InterestSub('tennis', 'Tennis'),
    InterestSub('volleyball', 'Volleyball'),
    InterestSub('swimming', 'Swimming & Diving'),
    InterestSub('track', 'Track & Field'),
    InterestSub('cross_country', 'Cross Country'),
    InterestSub('lacrosse', 'Lacrosse'),
    InterestSub('field_hockey', 'Field Hockey'),
    InterestSub('wrestling', 'Wrestling'),
  ]),
  InterestGroup('clubs', 'Clubs', Icons.groups, [
    InterestSub('science', 'Science'),
    InterestSub('technology', 'Technology & Robotics'),
    InterestSub('arts', 'Arts'),
    InterestSub('music', 'Music'),
    InterestSub('theater', 'Theater & Drama'),
    InterestSub('academic', 'Academic & Honor'),
    InterestSub('social', 'Social'),
    InterestSub('service', 'Service & Leadership'),
    InterestSub('debate', 'Debate & Speech'),
  ]),
  InterestGroup('fundraising', 'Fundraising', Icons.savings, []),
  InterestGroup('volunteering', 'Volunteering', Icons.volunteer_activism, []),
  InterestGroup('events', 'Events', Icons.event, []),
  InterestGroup('meetings', 'Meetings', Icons.forum, []),
];

/// Human-readable label for a stored interest key.
String interestLabel(String key) {
  final parts = key.split('.');
  final group = kInterestGroups.firstWhere(
    (g) => g.key == parts[0],
    orElse: () => const InterestGroup('', '', Icons.star, []),
  );
  if (group.key.isEmpty) return key;
  if (parts.length == 1) return group.label;
  final sub = group.subs.firstWhere(
    (s) => s.key == parts[1],
    orElse: () => InterestSub(parts[1], parts[1]),
  );
  return '${group.label} · ${sub.label}';
}
