/// The above Dart code prompts the user to enter their client id and client secret, then uses the
/// Google APIs client library to obtain a refresh token for accessing YouTube APIs.
import 'package:prompts/prompts.dart' as prompts;
import 'package:googleapis_auth/auth_io.dart';

void main() async {
  final clientId = prompts.get('Enter your client id:');
  final clientSecret = prompts.get('Enter your client secret');
  final client = await clientViaUserConsent(ClientId(clientId, clientSecret), [
    'https://www.googleapis.com/auth/youtube',
    'https://www.googleapis.com/auth/youtube.force-ssl',
    'https://www.googleapis.com/auth/youtube.channel-memberships.creator',
    'https://www.googleapis.com/auth/youtubepartner',
    'https://www.googleapis.com/auth/youtube.readonly',
    'https://www.googleapis.com/auth/youtube.upload',
  ], (String url) {
    print('Please go to the following URL and grant access:');
    print(url);
    print('');
  });
  print('Your refresh token:');
  print(client.credentials.refreshToken);
  client.close();
}
