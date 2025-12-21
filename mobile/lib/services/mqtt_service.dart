import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient client;
  final StreamController<String> _alertController =
      StreamController<String>.broadcast();
  final StreamController<String> _telemetryController =
      StreamController<String>.broadcast();

  Stream<String> get alertStream => _alertController.stream;
  Stream<String> get telemetryStream => _telemetryController.stream;

  // HiveMQ Credentials
  final String server = '3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'hivemq.webclient.1766077121308';
  final String password = '!tL29;S7p#0jCTFmvcM<';

  Future<void> connect(String deviceId) async {
    client = MqttServerClient.withPort(server,
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}', port);
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.keepAlivePeriod = 20;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.logging(on: false);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
            'flutter_client_${DateTime.now().millisecondsSinceEpoch}')
        .withWillTopic('willtopic')
        .withWillMessage('MyWillMessage')
        .startClean()
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      print('Connecting to MQTT...');
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTT Client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      print('MQTT Socket exception - $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT Connected');
      _subscribe(deviceId);
    } else {
      print('MQTT Connection failed - status is ${client.connectionStatus}');
      client.disconnect();
    }
  }

  void publish(String topic, String message) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT Client not connected, cannot publish');
      throw Exception('MQTT Client not connected');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _subscribe(String deviceId) {
    const topicAlert = 'baby/+/alert';
    const topicSensor = 'baby/+/sensor';

    client.subscribe(topicAlert, MqttQos.atMostOnce);
    client.subscribe(topicSensor, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final topic = c[0].topic;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('MQTT Message: $topic -> $pt');

      if (topic.endsWith('/alert')) {
        _alertController.add(pt);
      } else if (topic.endsWith('/sensor')) {
        _telemetryController.add(pt);
      }
    });
  }

  void onConnected() {
    print('MQTT Connected callback');
  }

  void onDisconnected() {
    print('MQTT Disconnected callback');
  }
}
