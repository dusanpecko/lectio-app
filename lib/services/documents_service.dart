import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pdf_document.dart';
import '../utils/app_logger.dart';

/// Vyhodené, keď používateľ nemá prístup k Dokumentom (HTTP 401/403).
class DocumentsAccessException implements Exception {
  const DocumentsAccessException();
}

/// Načítavanie sekcie „Dokumenty".
///
/// Prístup je viazaný na rolu `pastoral_council` alebo `admin` v tabuľke
/// `users`. Dáta sa ťahajú výhradne cez backend API (`/api/dokumenty`), pretože
/// RLS na `pdf_documents` priamy Supabase prístup pre `pastoral_council`
/// blokuje — API beží na service role a samo overuje rolu.
class DocumentsService {
  DocumentsService._();
  static final DocumentsService instance = DocumentsService._();

  static const Set<String> allowedRoles = {'pastoral_council', 'admin'};

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Rola aktuálneho používateľa (alebo null).
  Future<String?> fetchRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return data?['role'] as String?;
    } catch (e) {
      appLogger.e('❌ DocumentsService.fetchRole: $e');
      return null;
    }
  }

  /// Má používateľ prístup k Dokumentom?
  Future<bool> hasAccess() async {
    final role = await fetchRole();
    return role != null && allowedRoles.contains(role);
  }

  Map<String, String> get _headers {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Zoznam dokumentov. Vyhodí [DocumentsAccessException] pri 401/403.
  Future<List<PdfDocument>> fetchDocuments() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/dokumenty'),
      headers: _headers,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const DocumentsAccessException();
    }
    if (res.statusCode != 200) {
      throw Exception('Documents list failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['documents'] as List<dynamic>? ?? []);
    return list
        .map((e) => PdfDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detail dokumentu + jeho kapitoly.
  Future<({PdfDocument document, List<DocChapter> chapters})> fetchDetail(
    String slug,
  ) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/dokumenty/$slug'),
      headers: _headers,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const DocumentsAccessException();
    }
    if (res.statusCode != 200) {
      throw Exception('Document detail failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final document =
        PdfDocument.fromJson(body['document'] as Map<String, dynamic>);
    final chapters = (body['chapters'] as List<dynamic>? ?? [])
        .map((e) => DocChapter.fromJson(e as Map<String, dynamic>))
        .toList();
    return (document: document, chapters: chapters);
  }
}
