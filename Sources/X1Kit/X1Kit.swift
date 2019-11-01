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

enum X1MouseButton : UInt8 {
    case Left = 0
    case Right = 1
    case Middle = 2
}

protocol X1KitMouseDelegate : class {
    func connectedStateDidChange(identifier:UUID, isConnected: Bool)
    func mouseDidMove(identifier:UUID, x: Int8, y: Int8)
    func mouseDown(identifier:UUID, button: X1MouseButton)
    func mouseUp(identifier:UUID, button: X1MouseButton)
    func wheelDidScroll(identifier:UUID, z: Int8)
}

class X1Mouse: NSObject {
    var centralManager: CBCentralManager!
    var x1Array: [CBPeripheral] = []
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

extension CBCharacteristic {
    private struct X1KitState {
        static var buttonsState: UInt8 = 0
    }
    
    var x1LastButtonsState:UInt8 {
        get {
            return X1KitState.buttonsState;
        }
        
        set(newValue) {
            X1KitState.buttonsState = newValue;
        }
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
                x1Array.removeAll()
                break
                
            case .poweredOn:
                x1Array = centralManager.retrieveConnectedPeripherals(withServices: [X1Mouse.X1Service])
                
                for x1 in x1Array {
                    x1.delegate = self

                    centralManager.connect(x1)
                }
                
                centralManager.scanForPeripherals(withServices: [X1Mouse.X1Service], options: nil);
            
            default:
                break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (!x1Array.contains(peripheral)) {
            x1Array.append(peripheral)
            
            peripheral.delegate = self
            
            centralManager.connect(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.connectedStateDidChange(identifier: peripheral.identifier, isConnected: true)
        
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.connectedStateDidChange(identifier: peripheral.identifier, isConnected: false)
        
        centralManager.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        centralManager.connect(peripheral);
    }
}

extension X1Mouse: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if (service.uuid==X1Mouse.X1Service) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            switch(characteristic.uuid) {
                case X1Mouse.characteristicProtocolMode:
                    /* select boot mode protocol, allows direct access to mouse */
                    peripheral.writeValue(Data(bytes:[0], count:1), for: characteristic, type: CBCharacteristicWriteType.withoutResponse)

                case X1Mouse.characteristicReport:
                    peripheral.discoverDescriptors(for: characteristic);
                
                default:
                    break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let descriptors = characteristic.descriptors else { return }
        
        for descriptor in descriptors {
            peripheral.readValue(for: descriptor);
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if (descriptor.uuid==X1Mouse.descriptorReportReference) {
            if let value = descriptor.value as? NSData {
                /* report reference is 2 bytes long */
                
                if value.count != 2 {
                    return
                }
                
                let reportId = (UInt16(value[0])<<8) | (UInt16(value[1]))
                
                switch(reportId) {
                    case X1Mouse.xyReport, X1Mouse.wheelAndButtonsReport:
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
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (characteristic.uuid==X1Mouse.characteristicReport) {
            for descriptor in characteristic.descriptors!{
                if (descriptor.uuid==X1Mouse.descriptorReportReference) {
                    if let value = descriptor.value as? NSData {
                        /* check report contains 3 bytes, both xy & buttons reports are 3 bytes long */
                        
                        if (value.count != 2) {
                            continue
                        }
                        
                        let reportId = (UInt16(value[0])<<8) | (UInt16(value[1]))
                        
                        switch(reportId) {
                            case X1Mouse.xyReport:
                                if let reportData = characteristic.value as NSData? {
                                    if (reportData.count != 3) {
                                        continue
                                    }
                                    
                                    delegate?.mouseDidMove(identifier: peripheral.identifier, x: Int8.init(bitPattern:reportData[0]), y: Int8.init(bitPattern:reportData[1]))
                                }
                                break
                                
                            case X1Mouse.wheelAndButtonsReport:
                                if let reportData = characteristic.value as NSData? {
                                    if (reportData.count != 3) {
                                        continue
                                    }
                                    
                                    if (characteristic.x1LastButtonsState != UInt8.init(reportData[0])) {
                                        for bit:UInt8 in 0...2 {
                                            if ( ((reportData[0]) & (1<<bit)) != ((characteristic.x1LastButtonsState & (1<<bit))) ) {
                                                if (((reportData[0]) & (1<<bit))==(1<<bit)) {
                                                    delegate?.mouseDown(identifier: peripheral.identifier, button: X1MouseButton(rawValue: bit)!)
                                                }
                                                else {
                                                    delegate?.mouseUp(identifier: peripheral.identifier, button: X1MouseButton(rawValue: bit)!)
                                                }
                                            }
                                        }
                                        
                                        characteristic.x1LastButtonsState = UInt8.init(reportData[0])
                                    }
                                        
                                    if (Int8.init(bitPattern: reportData[1]) != 0) {
                                        delegate?.wheelDidScroll(identifier: peripheral.identifier, z: Int8.init(bitPattern: reportData[1]))
                                    }
                                }
                                break
                            
                            default:
                                break
                        }
                    }
                }
            }
        }
    }
}
