import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  Future<Map<String, String>> getCityAndState() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception(
        'Ative a localização do dispositivo para preencher automaticamente.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception(
        'Permissão de localização não concedida. Você pode preencher os dados manualmente.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'A permissão de localização está bloqueada nas configurações do dispositivo.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'zoom': '10',
      'addressdetails': '1',
    });
    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': 'pt-BR',
            'User-Agent': 'Fidelito/1.0 (location lookup)',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível identificar a cidade pela localização.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final address = Map<String, dynamic>.from(data['address'] ?? {});
    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                address['county'] ??
                '')
            .toString()
            .trim();
    final state = (address['state'] ?? '').toString().trim();

    if (city.isEmpty) {
      throw Exception(
        'Não foi possível identificar a cidade pela localização. Preencha manualmente.',
      );
    }

    return {'city': city, 'state': _stateAbbreviation(state)};
  }

  String _stateAbbreviation(String state) {
    const states = <String, String>{
      'Acre': 'AC',
      'Alagoas': 'AL',
      'Amapá': 'AP',
      'Amazonas': 'AM',
      'Bahia': 'BA',
      'Ceará': 'CE',
      'Distrito Federal': 'DF',
      'Espírito Santo': 'ES',
      'Goiás': 'GO',
      'Maranhão': 'MA',
      'Mato Grosso': 'MT',
      'Mato Grosso do Sul': 'MS',
      'Minas Gerais': 'MG',
      'Pará': 'PA',
      'Paraíba': 'PB',
      'Paraná': 'PR',
      'Pernambuco': 'PE',
      'Piauí': 'PI',
      'Rio de Janeiro': 'RJ',
      'Rio Grande do Norte': 'RN',
      'Rio Grande do Sul': 'RS',
      'Rondônia': 'RO',
      'Roraima': 'RR',
      'Santa Catarina': 'SC',
      'São Paulo': 'SP',
      'Sergipe': 'SE',
      'Tocantins': 'TO',
    };
    return states[state] ?? (state.length == 2 ? state.toUpperCase() : state);
  }
}
