import 'package:flutter/material.dart';

class DetailItem {
  const DetailItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
    this.isTags = false,
    this.tags = const [],
    this.isLink = false,
    this.uri,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;
  final bool isTags;
  final List<String> tags;
  final bool isLink;
  final Uri? uri;
}