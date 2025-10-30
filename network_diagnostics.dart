import 'dart:io';

void main() async {
  print('🔍 Starting network diagnostics...');

  // Test basic internet connectivity
  print('\n1. Testing basic internet connectivity...');
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print('✅ Basic internet connection: OK');
    } else {
      print('❌ Basic internet connection: FAILED');
    }
  } catch (e) {
    print('❌ Basic internet connection: FAILED - $e');
  }

  // Test Supabase host specifically
  print('\n2. Testing Supabase host connectivity...');
  try {
    final result = await InternetAddress.lookup(
      'unnijykbupxguogrkolj.supabase.co',
    );
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print('✅ Supabase host resolution: OK');
      print('   Host IP: ${result[0].address}');
    } else {
      print('❌ Supabase host resolution: FAILED');
    }
  } catch (e) {
    print('❌ Supabase host resolution: FAILED - $e');
  }

  // Test HTTP connection to Supabase
  print('\n3. Testing HTTP connection to Supabase...');
  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 10);

    final request = await client.getUrl(
      Uri.parse(
        'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/news/images/lectio-divina-app-icon.png',
      ),
    );
    request.headers.set('User-Agent', 'LectioDivina/1.0');

    final response = await request.close();
    print('✅ HTTP connection: OK (Status: ${response.statusCode})');

    client.close();
  } catch (e) {
    print('❌ HTTP connection: FAILED - $e');
  }

  // Test specific audio file
  print('\n4. Testing specific audio file URL...');
  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 10);

    final request = await client.headUrl(
      Uri.parse(
        'https://unnijykbupxguogrkolj.supabase.co/storage/v1/object/public/audio-files/lectio/462/biblia_1_audio_sk_1759856024236.mp3',
      ),
    );
    request.headers.set('User-Agent', 'LectioDivina/1.0');
    request.headers.set('Accept', 'audio/*');

    final response = await request.close();
    print('✅ Audio file accessibility: OK (Status: ${response.statusCode})');
    print(
      '   Content-Type: ${response.headers.value('content-type') ?? 'Unknown'}',
    );
    print(
      '   Content-Length: ${response.headers.value('content-length') ?? 'Unknown'}',
    );

    client.close();
  } catch (e) {
    print('❌ Audio file accessibility: FAILED - $e');
  }

  print('\n🏁 Network diagnostics completed.');
}
