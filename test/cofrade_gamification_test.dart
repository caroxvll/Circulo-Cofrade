import 'package:cofradeo/features/forums/constants/cofrade_ranks.dart';
import 'package:cofradeo/features/forums/constants/cofrade_trophies.dart';
import 'package:cofradeo/features/forums/utils/cofrade_gamification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trophyPointsFromStats', () {
    test('first reply unlocks cofrade de a pie', () {
      const stats = CofradeForumStats(validReplyCount: 1);
      expect(trophyPointsFromStats(stats), 1);
      expect(cofradeRankFromStats(stats).title, 'Hermano');
    });

    test('reactions weigh more than spam replies alone', () {
      const spamOnly = CofradeForumStats(validReplyCount: 100);
      const quality = CofradeForumStats(
        validReplyCount: 30,
        reactionsReceived: 100,
      );

      expect(trophyPointsFromStats(spamOnly), lessThan(trophyPointsFromStats(quality)));
    });
  });

  group('cofradeRankForPoints', () {
    test('maps to official ladder', () {
      expect(cofradeRankForPoints(0).title, 'Cofrade de a pie');
      expect(cofradeRankForPoints(56).title, 'Diputado de Tramo');
      expect(cofradeRankForPoints(163).title, 'Hermano Mayor');
    });

    test('ladder is strictly ascending', () {
      for (var i = 1; i < CofradeRanks.ladder.length; i++) {
        expect(
          CofradeRanks.ladder[i].minPoints,
          greaterThan(CofradeRanks.ladder[i - 1].minPoints),
        );
      }
    });
  });

  group('isValidForumReplyContent', () {
    test('rejects short filler', () {
      expect(isValidForumReplyContent('ok'), isFalse);
      expect(isValidForumReplyContent('a' * 20), isTrue);
    });
  });

  group('nearestTrophyProgress', () {
    test('suggests closest locked trophy', () {
      const stats = CofradeForumStats(
        validReplyCount: 9,
        reactionsReceived: 1,
      );
      final nearest = nearestTrophyProgress(stats, limit: 1);
      expect(nearest.single.trophy.id, 'replies_10');
      expect(nearest.single.deficit, 1);
    });
  });

  group('achievedCofradeRanks', () {
    test('includes past ranks but not future ones', () {
      final achieved = achievedCofradeRanks(56);
      expect(achieved.last.title, 'Diputado de Tramo');
      expect(achieved.first.title, 'Cofrade de a pie');
      expect(achieved.length, greaterThan(10));
      expect(
        achieved.any((r) => r.title == 'Hermano Mayor'),
        isFalse,
      );
    });
  });
}
