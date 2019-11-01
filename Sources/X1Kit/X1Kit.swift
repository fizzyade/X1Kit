/* X1Kit.swift
 *
 * This file is part of X1Kit, a swift framework for using the Citrix X1 mouse.
 *
 * Copyright (c) 2019 Adrian Carpenter
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import CoreBluetooth

protocol X1KitMouseDelegate {
    func connectedStateDidChange(isConnected: Bool)
    func mouseDidMove(x: Int, y: Int)
    func buttonsDidChange(state: Int)
    func wheelDidScroll(z: Int)
}

class X1Mouse: NSObject {
    var centralManager: CBCentralManager!
    weak var delegate: X1KitMouseDelegate?
    
    static let X1Service = CBUUID(string: "2B080000-BDB5-F6EB-24AE-9D6AB282AB63")
    static let characteristicProtocolMode = CBUUID(string: "2A4E");
    static let characteristicReport = CBUUID(string: "2A4D");
    static let descriptorReportReference = CBUUID(string: "2908");
    static let wheelAndButtonsReport: UInt16 = 0x0101;
    static let xyReport: UInt16 = 0x0201;
    
    func start() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

extension X1Mouse: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .unknown:
                break
                
            case .resetting:
                break
                
            case .unsupported:
                break
                
            case .unauthorized:
                break
                
            case .poweredOff:
                break
                
            case .poweredOn:
                let peripheralList = centralManager.retrieveConnectedPeripherals(withServices: [X1Service])
                
                for peripheral in peripheralLost {
                    peripheral.delegate = self

                    centralManager.connect(peripheral)
                }
                
            default:
                break;
        }
    }
    
    func centralManager(_ central: CBCentralManager, 
                  didConnect peripheral: CBPeripheral) {
        delegate?.connectedStateDidChange(isConnected: true)
    }
    
    func centralManager(_ central: CBCentralManager, 
     didDisconnectPeripheral peripheral: CBPeripheral, 
                       error: Error?) {
        delegate?.connectedStateDidChange(isConnected: false)
        
        centralManager.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, 
            didFailToConnect peripheral: CBPeripheral, 
                       error: Error?) {
        centralManager.connect(peripheral);
    }
}

extension X1Mouse: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if (service.uuid==X1Service) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            switch(characteristic.uuid) {
                case characteristicProtocolMode:
                    /* select boot mode protocol */
                    peripheral.writeValue(Data(bytes:[0], count:1), for: characteristic, type: CBCharacteristicWriteType.withoutResponse)

                case characteristicReport:
                    peripheral.discoverDescriptors(for: characteristic);
                
                default:
                    break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if ((characteristic.descriptors) != nil) {
            for descriptor in characteristic.descriptors!{
                peripheral.readValue(for: descriptor);
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if (descriptor.uuid==descriptorReportReference) {
            if let value = descriptor.value as? NSData {
                let reportId = (UInt16(value[0])<<8) | (UInt16(value[1]))
                
                switch(reportId) {
                    case xyReport, wheelAndButtonsReport:
                        peripheral.setNotifyValue(true, for: descriptor.characteristic)
                        
                        if (descriptor.characteristic.properties.contains(.notify)) {
                            peripheral.setNotifyValue(true, for: descriptor.characteristic)
                        }

                        break
                    
                    default:
                        break
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?) {
        if (characteristic.uuid==characteristicReport) {
            for descriptor in characteristic.descriptors!{
                if (descriptor?.uuid==descriptorReportReference) {
                    if let value = descriptor.value as? NSData {
                        let reportId = (UInt16(value[0])<<8) | (UInt16(value[1]))
                        
                        switch(reportId) {
                            case xyReport:
                                delegate?.mouseDidMove(x: 0, y: 0)
                                break
                                
                            case wheelAndButtonsReport:
                                delegate?.buttonsDidChange(state: 0)
                                delegate?.wheelDidScroll(z: 0)
                                break
                        }
                    }
                }
            }
        }
    }
}
