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
  
  /// Build time sync packet (with timezone adjustment matching z1.java)
  static List<int> buildTimeSync(DateTime time) {
    // The CrRePa firmware internal RTC treats sync timestamps as China Standard Time (GMT+8).
    // Exactly matches decompiled z1.java:
    // Convert the local date/time fields to UTC representation minus 8 hours,
    // so when the watch interprets it in GMT+8, it displays the user's exact local wall-clock time.
    final localTimeAsUtc = DateTime.utc(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
      time.second,
    );
    final ts = (localTimeAsUtc.millisecondsSinceEpoch ~/ 1000) - (8 * 3600);
    final payload = [
      (ts >> 24) & 0xFF,
      (ts >> 16) & 0xFF,
      (ts >> 8) & 0xFF,
      ts & 0xFF,
      8, // day of week constant (confirmed from z1.java)
    ];
    return buildPacket(ProtocolConstants.cmdTimeSync, payload);
  }
  
  /// Build timezone sync packet (confirmed from z1.java c())
  static List<int> buildTimezoneSync(DateTime time) {
    final offsetSeconds = time.timeZoneOffset.inSeconds;
    final payload = [
      7, // constant from z1.java
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
  
  /// Build set time system packet (0=12h, 1=24h - confirmed from CRPTimeSystemType.java & z1.java)
  static List<int> buildSetTimeSystem(bool is24Hour) {
    return buildPacket(ProtocolConstants.cmdTimeSystemSet, [is24Hour ? 1 : 0]);
  }
  
  /// Build switch display watch face packet (cmd 0x19 - confirmed from s2.java b(int) & a.java sendDisplayWatchFace)
  static List<int> buildSwitchDisplayWatchFace(int index) {
    return buildPacket(ProtocolConstants.cmdDisplayWatchFace, [index]);
  }

  /// Build Jieli watch face ID switch packet (cmd 0xB4, sub-cmd 17 - confirmed from s2.java a(int, boolean))
  static List<int> buildJieliWatchFaceId(int id, {bool enable = true}) {
    final high = (id >> 8) & 0xFF;
    final low = id & 0xFF;
    return buildPacket(ProtocolConstants.cmdWatchFace, enable ? [17, high, low, 1] : [17, high, low]);
  }

  /// Build watch face layout packet (cmd 0x38 - confirmed from d2.java a(CRPWatchFaceLayoutInfo))
  static List<int> buildWatchFaceLayout({
    int timePosition = 0,
    int timeTopContent = 1,
    int timeBottomContent = 2,
    int textColor = 0xFFFF,
  }) {
    final payload = List<int>.filled(37, 0);
    payload[0] = timePosition;
    payload[1] = timeTopContent;
    payload[2] = timeBottomContent;
    payload[3] = (textColor >> 8) & 0xFF;
    payload[4] = textColor & 0xFF;
    return buildPacket(0x38, payload);
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
