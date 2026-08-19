import 'constants.dart';

class ProtocolParser {
  /// Build a CrRePa packet
  static List<int> buildPacket(int cmd, List<int> payload) {
    final totalLen = ProtocolConstants.frameHeaderLen + payload.length;
    final packet = List<int>.filled(totalLen, 0);
    
    packet[0] = ProtocolConstants.frameMagic1;
    packet[1] = ProtocolConstants.frameMagic2;
    packet[2] = totalLen <= 20 ? 0x10 : 0x20;
    packet[3] = totalLen;
    packet[4] = cmd;
    
    if (payload.isNotEmpty) {
      packet.setRange(ProtocolConstants.frameHeaderLen, totalLen, payload);
    }
    
    return packet;
  }
  
  /// Parse a CrRePa response
  static ({int cmd, List<int> payload})? parsePacket(List<int> data) {
    if (data.length < ProtocolConstants.frameHeaderLen) {
      return null;
    }
    if (data[0] != ProtocolConstants.frameMagic1 || 
        data[1] != ProtocolConstants.frameMagic2) {
      return null;
    }
    
    final cmd = data[4];
    final List<int> payload = data.length > ProtocolConstants.frameHeaderLen
        ? data.sublist(ProtocolConstants.frameHeaderLen)
        : <int>[];
    
    return (cmd: cmd, payload: payload);
  }
  
  /// Parse HR history response (cmd 0xAB)
  static List<({DateTime timestamp, int bpm})>? parseHRHistory(List<int> payload) {
    if (payload.length < 7 || payload[0] != 0) return null;
    
    final records = <({DateTime timestamp, int bpm})>[];
    
    for (int i = 2; i + 4 < payload.length; i += 5) {
      final bpm = payload[i] & 0xFF;
      final ts = payload[i + 1] | 
                 (payload[i + 2] << 8) | 
                 (payload[i + 3] << 16) | 
                 (payload[i + 4] << 24);
      
      records.add((
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        bpm: bpm,
      ));
    }
    
    return records;
  }
  
  /// Parse step history (cmd 0x33)
  static ({int steps, double distanceKm, int calories})? parseStepHistory(
      List<int> payload) {
    if (payload.length < 10) return null;
    
    final steps = payload[1] | (payload[2] << 8) | (payload[3] << 16);
    final distance = payload[4] | (payload[5] << 8) | (payload[6] << 16);
    final calories = payload[7] | (payload[8] << 8) | (payload[9] << 16);
    
    return (
      steps: steps,
      distanceKm: distance / 1000.0,
      calories: calories,
    );
  }
  
  /// Parse battery level (standard BLE 0x2A19)
  static int? parseBattery(List<int> data) {
    if (data.isEmpty) return null;
    return data[0];
  }
  
  /// Parse live HR measurement (0x2A37)
  static ({int bpm, int rrInterval})? parseLiveHR(List<int> data) {
    if (data.length < 2) return null;
    
    final bpm = data[1] & 0xFF;
    int rrInterval = 1024;
    
    if (data.length >= 4) {
      rrInterval = data[2] | (data[3] << 8);
    }
    
    return (bpm: bpm, rrInterval: rrInterval);
  }
  
  /// Build time sync packet (with timezone adjustment)
  static List<int> buildTimeSync(DateTime time) {
    // Convert to UTC first
    final utc = time.toUtc();
    final ts = utc.millisecondsSinceEpoch ~/ 1000;
    final payload = [
      (ts >> 24) & 0xFF,
      (ts >> 16) & 0xFF,
      (ts >> 8) & 0xFF,
      ts & 0xFF,
      8, // day of week constant
    ];
    return buildPacket(ProtocolConstants.cmdTimeSync, payload);
  }
  
  /// Build timezone sync packet
  static List<int> buildTimezoneSync(DateTime time) {
    final offsetSeconds = time.timeZoneOffset.inSeconds;
    final payload = [
      7, // constant
      0,
      offsetSeconds & 0xFF,
      (offsetSeconds >> 8) & 0xFF,
      (offsetSeconds >> 16) & 0xFF,
      (offsetSeconds >> 24) & 0xFF,
    ];
    return buildPacket(ProtocolConstants.cmdTimezone, payload);
  }
  
  /// Build query time system packet (12h/24h)
  static List<int> buildQueryTimeSystem() {
    return buildPacket(ProtocolConstants.cmdTimeSystemQuery, []);
  }
  
  /// Build set time system packet (0=12h, 1=24h)
  static List<int> buildSetTimeSystem(bool is24Hour) {
    return buildPacket(ProtocolConstants.cmdTimeSystemSet, [is24Hour ? 1 : 0]);
  }
  
  /// Build bond state packet
  static List<int> buildBondState(bool bound) {
    return buildPacket(ProtocolConstants.cmdBondState, [4, bound ? 1 : 0]);
  }
  
  /// Build watch face switch packet (photo=1, video=2)
  static List<int> buildSwitchWatchFace(int type) {
    return buildPacket(ProtocolConstants.cmdWatchFace, [35, type]);
  }
  
  /// Build get watch face info packet
  static List<int> buildGetWatchFaceInfo(int type) {
    return buildPacket(ProtocolConstants.cmdWatchFace, [22, type]);
  }
  
  /// Build bond create packet
  static List<int> buildBondCreate() {
    return buildPacket(ProtocolConstants.cmdBondState, [4, 1]);
  }
  
  /// Build HR history request
  static List<int> buildGetHRHistory() {
    return buildPacket(ProtocolConstants.cmdHRHistory, [0]);
  }
  
  /// Build step history request
  static List<int> buildGetStepHistory(int dayOffset) {
    return buildPacket(ProtocolConstants.cmdStepHistory, [dayOffset]);
  }
}
