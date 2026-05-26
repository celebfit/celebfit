import 'package:flutter/material.dart';

enum CelebGender { female, male }

class EyebrowStyle {
  const EyebrowStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.tags,
    required this.mockColor,
    required this.gender,
    this.previewAsset,
    this.apiEnabled = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final List<String> tags;
  final Color mockColor;
  final CelebGender gender;
  final String? previewAsset;
  final bool apiEnabled;
}

const kStyleFilters = ['자연스러운', '화사한 인상', '또렷한 인상'];

const kFemaleEyebrowStyles = [
  EyebrowStyle(
    id: 'go_yoonjung',
    name: '고윤정',
    subtitle: '자연형',
    description: '가늘고 부드러운 라인. 생기 있으면서도 편안한 인상.',
    tags: ['자연스러운'],
    mockColor: Color(0xFFC4A882),
    gender: CelebGender.female,
    previewAsset: 'assets/celebs/go_yoonjung.jpg',
    apiEnabled: true,
  ),
  EyebrowStyle(
    id: 'shin_sekyung',
    name: '신세경',
    subtitle: '세미 아치',
    description: '은은한 아치 곡선. 또렷하지만 세련된 분위기.',
    tags: ['자연스러운', '또렷한 인상'],
    mockColor: Color(0xFF8888A0),
    gender: CelebGender.female,
    previewAsset: 'assets/celebs/shin_sekyung.jpg',
    apiEnabled: true,
  ),
  EyebrowStyle(
    id: 'hong_sooju',
    name: '홍수주',
    subtitle: '직선형',
    description: '깔끔한 일자 라인. 단정하고 시크한 느낌.',
    tags: ['또렷한 인상'],
    mockColor: Color(0xFFA07878),
    gender: CelebGender.female,
    previewAsset: 'assets/celebs/hong_sooju.jpg',
    apiEnabled: true,
  ),
];

const kMaleEyebrowStyles = <EyebrowStyle>[
  EyebrowStyle(
    id: 'male_soon',
    name: '남성 스타일',
    subtitle: '준비중',
    description: '차분·또렷·내추럴 등 남성 연예인 눈썹 스타일을 준비하고 있습니다.',
    tags: ['또렷한 인상'],
    mockColor: Color(0xFF7A8FA8),
    gender: CelebGender.male,
    apiEnabled: false,
  ),
];

const kEyebrowStyles = [
  ...kFemaleEyebrowStyles,
  ...kMaleEyebrowStyles,
  EyebrowStyle(
    id: 'natural',
    name: '내추럴',
    subtitle: '자연스러움',
    description: '범용 자연형 스타일',
    tags: ['자연스러운'],
    mockColor: Color(0xFFB8A0C8),
    gender: CelebGender.female,
  ),
  EyebrowStyle(
    id: 'soft_arch',
    name: '소프트 아치',
    subtitle: '부드러운 곡선',
    description: '부드러운 곡선형 스타일',
    tags: ['화사한 인상'],
    mockColor: Color(0xFFD4CCE8),
    gender: CelebGender.female,
  ),
  EyebrowStyle(
    id: 'straight',
    name: '일자형',
    subtitle: '또렷한 인상',
    description: '일자형 스타일',
    tags: ['또렷한 인상'],
    mockColor: Color(0xFF9B8FD8),
    gender: CelebGender.female,
  ),
];

const kApiEyebrowStyles = kFemaleEyebrowStyles;

class CelebrityMatch {
  const CelebrityMatch({
    required this.name,
    required this.styleLabel,
    required this.percent,
    required this.previewAsset,
    this.showCrown = false,
  });

  final String name;
  final String styleLabel;
  final int percent;
  final String previewAsset;
  final bool showCrown;
}

const kMockCelebrityMatches = [
  CelebrityMatch(
    name: '고윤정',
    styleLabel: '자연형',
    percent: 82,
    previewAsset: 'assets/celebs/go_yoonjung.jpg',
    showCrown: true,
  ),
  CelebrityMatch(
    name: '신세경',
    styleLabel: '세미 아치',
    percent: 76,
    previewAsset: 'assets/celebs/shin_sekyung.jpg',
  ),
  CelebrityMatch(
    name: '홍수주',
    styleLabel: '직선형',
    percent: 71,
    previewAsset: 'assets/celebs/hong_sooju.jpg',
  ),
];

class ResultScore {
  const ResultScore({required this.label, required this.value});
  final String label;
  final int value;
}

const kMockResultScores = [
  ResultScore(label: '조화로움', value: 95),
  ResultScore(label: '자연스러움', value: 90),
  ResultScore(label: '균형감', value: 91),
];
