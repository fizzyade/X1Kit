# X1Kit

X1Kit is a Swift framework that allows applications to make use of the Citrix X1 mouse.

## Requirements

A Citrix X1 mouse, this is a mouse which provides a Bluetooth Low Energy protocol to report position and button states, it is capable of operating as a standard BLE mouse or in a an additional mode which allows iOS applications to directly access the mouse without any operating system support,

You should ensure that the mouse is correctly paired with the iOS device,

## Usage

Import X1Kit at the top of the Swift file.

```swift
import X1Kit
```

To use CoreBluetooth you will need to add the following keys (with a value explaining the use of bluetooth) to your application Info.plist, failure to add the appropriate key will result in your application crashing.

iOS 13 or later:

```swift
NSBluetoothAlwaysUsageDescription
```

iOS 12 or earlier:


```swift
NSBluetoothPeripheralUsageDescription
```

The application should instantiate and instance of the X1Mouse class and the delegate set to receive updates from the mouse,

```swift
let theMouse = X1Mouse()

theMouse.delegate = self
```

The following protocol is defined and should be implemented.

```swift
protocol X1KitMouseDelegate {
    func connectedStateDidChange(isConnected: bool)
    func mouseDidMove(x: Int, y: Int)
    func buttonsDidChange(buttons: Int)
    func wheelDidScroll(z: Int)
}
```

## License

This project is open source and is released under the [MIT License](LICENSE.md)

Distributed as-is; no warranty is given.