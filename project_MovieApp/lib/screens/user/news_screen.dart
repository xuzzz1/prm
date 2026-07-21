import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/news_provider.dart';
import '../../models/news_item.dart';
import '../../themes/app_theme.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secondaryAnthracite,
      appBar: AppBar(
        backgroundColor: AppTheme.secondaryAnthracite,
        title: const Text(
          "Tin tức",
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<NewsProvider>(
        builder: (context, newsProvider, child) {
          if (newsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAmber),
            );
          }

          if (newsProvider.newsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.newspaper_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Chưa có tin tức nào",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => newsProvider.loadNews(),
            color: AppTheme.primaryAmber,
            backgroundColor: AppTheme.secondaryAnthracite,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: newsProvider.newsList.length,
              itemBuilder: (context, index) {
                final news = newsProvider.newsList[index];
                return _NewsCard(news: news);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(news: news),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryAnthracite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: news.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 180,
                      color: AppTheme.secondaryAnthracite,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryAmber),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 180,
                      color: AppTheme.secondaryAnthracite,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(news.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (news.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      news.body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
