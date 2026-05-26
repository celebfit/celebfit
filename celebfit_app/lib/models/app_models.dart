import 'package:flutter/material.dart';

class EyebrowStyle {
  const EyebrowStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.tags,
    required this.mockColor,
  });

  final String id;
  final String name;
  final String subtitle;
  final List<String> tags;
  final Color mockColor;
}

const kStyleFilters = ['자연스러운', '화사한 인상', '또렷한 인상'];

const kEyebrowStyles = [
  EyebrowStyle(
    id: 'go_yoonjung',
    name: '자연형',
    subtitle: '고윤정 스타일',
    tags: ['자연스러운'],
    mockColor: Color(0xFFC4A882),
  ),
  EyebrowStyle(
    id: 'shin_sekyung',
    name: '세미 아치',
    subtitle: '신세경 스타일',
    tags: ['자연스러운', '또렷한 인상'],
    mockColor: Color(0xFF8888A0),
  ),
  EyebrowStyle(
    id: 'hong_sooju',
    name: '직선형',
    subtitle: '홍수주 스타일',
    tags: ['또렷한 인상'],
    mockColor: Color(0xFFA07878),
  ),
  EyebrowStyle(
    id: 'natural',
    name: '내추럴',
    subtitle: '자연스러움',
    tags: ['자연스러운'],
    mockColor: Color(0xFFB8A0C8),
  ),
  EyebrowStyle(
    id: 'soft_arch',
    name: '소프트 아치',
    subtitle: '부드러운 곡선',
    tags: ['화사한 인상'],
    mockColor: Color(0xFFD4CCE8),
  ),
  EyebrowStyle(
    id: 'straight',
    name: '일자형',
    subtitle: '또렷한 인상',
    tags: ['또렷한 인상'],
    mockColor: Color(0xFF9B8FD8),
  ),
];

class CelebrityMatch {
  const CelebrityMatch({
    required this.styleLabel,
    required this.name,
    required this.percent,
    this.showCrown = false,
  });

  final String styleLabel;
  final String name;
  final int percent;
  final bool showCrown;
}

const kMockCelebrityMatches = [
  CelebrityMatch(styleLabel: 'A', name: 'Style A · 자연형', percent: 82, showCrown: true),
  CelebrityMatch(styleLabel: 'B', name: 'Style B · 세미 아치', percent: 76),
  CelebrityMatch(styleLabel: 'C', name: 'Style C · 직선형', percent: 71),
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
