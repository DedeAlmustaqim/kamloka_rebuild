//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import gal
import geolocator_apple
import package_info_plus
import printing
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  GalPlugin.register(with: registry.registrar(forPlugin: "GalPlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PrintingPlugin.register(with: registry.registrar(forPlugin: "PrintingPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}
