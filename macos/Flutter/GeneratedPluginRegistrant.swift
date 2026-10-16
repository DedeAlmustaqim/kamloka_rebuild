//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import gal
import geolocator_apple
import in_app_purchase_storekit
import package_info_plus
import printing
import share_plus
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  GalPlugin.register(with: registry.registrar(forPlugin: "GalPlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  InAppPurchasePlugin.register(with: registry.registrar(forPlugin: "InAppPurchasePlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PrintingPlugin.register(with: registry.registrar(forPlugin: "PrintingPlugin"))
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}
