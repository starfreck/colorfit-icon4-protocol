/// CrRePa/Jieli CRP protocol constants for ColorFit Icon 4
library;

class ProtocolConstants {
  // GATT UUIDs (short forms used by the watch)
  static const String writeCharUuid = 'fee2';
  static const String writeCharAltUuid = 'fee5';
  static const String notifyCharUuid = 'fee3';
  static const String batteryCharUuid = '2a19';
  static const String hrMeasCharUuid = '2a37';
  
  // Frame format
  static const int frameMagic1 = 0xFE;
  static const int frameMagic2 = 0xEA;
  static const int frameHeaderLen = 5;
  
  // Commands
  static const int cmdTodaySteps = 0x32;
  static const int cmdStepHistory = 0x33;
  static const int cmdTodayHR = 0x37;
  static const int cmdSleepData = 0xBC;
  static const int cmdHRHistory = 0xAB;
  static const int cmdTimeSync = 0x31;
  static const int cmdDeviceVersion = 0x2E;
  static const int cmdMetricSystem = 0x2A;
  static const int cmdBondState = 0x81;
  static const int cmdTimezone = 0xBB;
  static const int cmdWatchFace = 0xB4;
  static const int cmdDisplayWatchFace = 0x19;
  static const int cmdTimeSystemQuery = 0x27;
  static const int cmdTimeSystemSet = 0x17;
}
