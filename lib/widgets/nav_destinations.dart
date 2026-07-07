import 'package:flutter/material.dart';

/// A top-level section of the app shown in the navigation.
class AppSection {
  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  const AppSection(this.label, this.route, this.icon, this.selectedIcon);
}

const List<AppSection> kSections = [
  AppSection('Home', '/', Icons.home_outlined, Icons.home),
  AppSection('Events', '/events', Icons.event_outlined, Icons.event),
  AppSection('Volunteer', '/volunteering', Icons.volunteer_activism_outlined,
      Icons.volunteer_activism),
  AppSection('Sponsors', '/sponsorships', Icons.handshake_outlined,
      Icons.handshake),
  AppSection('Donate', '/donate', Icons.favorite_outline, Icons.favorite),
  AppSection('Funding Request', '/funding', Icons.request_quote_outlined,
      Icons.request_quote),
  AppSection('Fundraisers', '/fundraisers', Icons.savings_outlined,
      Icons.savings),
  AppSection('Meetings', '/meetings', Icons.groups_outlined, Icons.groups),
  AppSection('Gallery', '/gallery', Icons.photo_library_outlined,
      Icons.photo_library),
  AppSection('FAQ', '/faq', Icons.help_outline, Icons.help),
];
