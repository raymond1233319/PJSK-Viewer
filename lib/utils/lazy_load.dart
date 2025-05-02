import 'dart:async';
import 'package:flutter/material.dart';

class LazyLoadUtility<T> {
  // Configuration
  final int pageSize;
  final ScrollController scrollController;
  final int scrollThreshold;
  final Duration debounceTime;
  
  // State
  List<T> allItems = [];
  List<T> filteredItems = [];
  int currentDisplayCount;
  bool isLoadingMore = false;
  Timer? _debounceTimer;
  
  // Optional callbacks
  final Function()? onLoadMoreStarted;
  final Function()? onLoadMoreFinished;
  
  LazyLoadUtility({
    required this.pageSize,
    required this.scrollController,
    this.scrollThreshold = 300,
    this.debounceTime = const Duration(milliseconds: 300),
    this.onLoadMoreStarted,
    this.onLoadMoreFinished,
    this.allItems = const [],
    List<T> filteredItems = const [],
  }) : currentDisplayCount = pageSize {
    _setupScrollListener();
  }
  
  void _setupScrollListener() {
    scrollController.addListener(() {
      // If we're near the bottom of the list
      if (scrollController.position.pixels >
          scrollController.position.maxScrollExtent - scrollThreshold) {
        // Cancel any existing timer
        _debounceTimer?.cancel();
        
        // Add delay before calling load more
        _debounceTimer = Timer(debounceTime, () {
          loadMoreItems();
        });
      }
    });
  }
  
  void loadMoreItems() {
    if (isLoadingMore) return; // Prevent multiple calls
    
    isLoadingMore = true;
    if (onLoadMoreStarted != null) onLoadMoreStarted!();
    
    // Only load more if there are more items to show
    if (currentDisplayCount < filteredItems.length) {
      // Increase by page size but don't exceed total items
      currentDisplayCount = (currentDisplayCount + pageSize).clamp(
        0,
        filteredItems.length,
      );
    }
    
    isLoadingMore = false;
    if (onLoadMoreFinished != null) onLoadMoreFinished!();
  }
  
  void updateFilteredItems(List<T> newFiltered) {
    filteredItems = newFiltered;
    resetPagination();
  }
  
  void resetPagination() {
    currentDisplayCount = pageSize.clamp(0, filteredItems.length);
    
    // Scroll to top
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void dispose() {
    _debounceTimer?.cancel();
  }
  
  // Helper methods for ListView usage
  int get itemCount {
    return currentDisplayCount < filteredItems.length 
        ? currentDisplayCount + 1 // +1 for loading indicator
        : currentDisplayCount;
  }
  
  bool isLoadingIndicator(int index) {
    return index == currentDisplayCount && currentDisplayCount < filteredItems.length;
  }
}