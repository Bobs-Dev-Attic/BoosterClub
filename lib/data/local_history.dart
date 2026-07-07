import '../models/content_models.dart';

/// A curated, built-in pack of real local history facts for Bethesda / Walter
/// Johnson HS / Montgomery County, Maryland. These are always available (no
/// network needed) so the "This Day in Wildcat History" card and the History
/// admin have local content even before anyone adds their own. A Contributor
/// can one-click import these and then edit or add to them.
///
/// Dates are the actual anniversaries where known, so they surface on the right
/// day; evergreen facts use Jan 1.
class LocalHistory {
  static List<HistoryFact> pack() => const [
        HistoryFact(
          id: 'lh-wj-founded',
          title: 'Walter Johnson High School opens',
          fact:
              'Walter Johnson High School opened in 1956 in Bethesda, Maryland, '
              'and has been home of the Wildcats ever since.',
          month: 9,
          day: 4,
          year: 1956,
        ),
        HistoryFact(
          id: 'lh-namesake',
          title: 'The school\'s namesake: "The Big Train"',
          fact:
              'The school is named for Walter "Big Train" Johnson, the Hall of '
              'Fame Washington Senators pitcher who later lived in Montgomery '
              'County and served as a county commissioner. He was born on '
              'November 6, 1887.',
          month: 11,
          day: 6,
          year: 1887,
        ),
        HistoryFact(
          id: 'lh-hall-of-fame',
          title: 'Walter Johnson enters the Hall of Fame',
          fact:
              'In 1936, Walter Johnson was among the first five players elected '
              'to the Baseball Hall of Fame, alongside Ty Cobb, Babe Ruth, '
              'Honus Wagner and Christy Mathewson.',
          month: 1,
          day: 1,
          year: 1936,
        ),
        HistoryFact(
          id: 'lh-moco-founded',
          title: 'Montgomery County is established',
          fact:
              'Montgomery County, Maryland was created in 1776 and named for '
              'General Richard Montgomery. Rockville is its county seat.',
          month: 9,
          day: 6,
          year: 1776,
        ),
        HistoryFact(
          id: 'lh-bethesda-name',
          title: 'How Bethesda got its name',
          fact:
              'Bethesda takes its name from the Bethesda Meeting House, a '
              'Presbyterian church established in the early 1800s — "Bethesda" '
              'refers to the healing pool in the Bible.',
          month: 1,
          day: 1,
        ),
        HistoryFact(
          id: 'lh-nih',
          title: 'A community of discovery',
          fact:
              'Bethesda is home to the National Institutes of Health and the '
              'Walter Reed National Military Medical Center, making it one of '
              'the country\'s leading centers for medical research.',
          month: 1,
          day: 1,
        ),
      ];
}
