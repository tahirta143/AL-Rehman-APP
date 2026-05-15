import 'dart:io' show Platform;
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

class ThermalPrinterService {
  final PrinterManager _manager = PrinterManager();

  Future<List<PrinterDevice>> scanPrinters({Duration timeout = const Duration(seconds: 4)}) async {
    // iOS mainly supports Bluetooth/Network for thermal printers
    // Android supports USB, Bluetooth, and Network
    final Set<PrinterConnectionType> types = {
      PrinterConnectionType.bluetooth,
      PrinterConnectionType.network,
    };
    
    if (Platform.isAndroid || Platform.isWindows || Platform.isMacOS) {
      types.add(PrinterConnectionType.usb);
    }

    return _manager.scanPrinters(
      timeout: timeout,
      types: types,
    );
  }

  Future<bool> printReceipt({
    required PrinterDevice printer,
    required Ticket ticket,
  }) async {
    try {
      await _manager.connect(printer);
      await _manager.printTicket(ticket);
      await _manager.disconnect();
      return true;
    } on PrinterException {
      try {
        await _manager.disconnect();
      } catch (_) {}
      return false;
    }
  }
}

