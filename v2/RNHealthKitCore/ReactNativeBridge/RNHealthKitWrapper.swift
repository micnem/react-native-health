import Foundation
import HealthKit

@objc(RNHealthKitWrapper)
class RNHealthKitWrapper: NSObject {
    var core: HealthKitCore?

    @objc
    func initHealthKit(_ read: Array<String>, write: Array<String>, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                let readTypes: Array<QuantityType> = read.compactMap { .init(rawValue: $0) }
                let writeTypes: Array<QuantityType> = write.compactMap { .init(rawValue: $0) }
                
                core = try await HealthKitCore.init(read: readTypes, write: writeTypes)
                resolve(true)
            } catch {
                reject("initHealthKit", error.localizedDescription, error)
            }
        }
    }

    @objc
    func getQuantitySamples(_ query: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                guard
                    let unit = (query["unit"] as? String)?.hkUnit,
                    let type = query["type"] as? String,
                    let sampleType: QuantityType = .init(rawValue: type)
                else {
                        reject("getQuantitySamples", "Invalid parameters, check the unit and type.", nil)
                        return
                }
                let parameters = QuantityQuery(
                    startDate: (query["startDate"] as? String)?.fromIsoStringToDate(),
                    endDate: (query["endDate"] as? String)?.fromIsoStringToDate(),
                    isUserEntered: query["isUserEntered"] as? Bool,
                    limit: query["limit"] as? Int ?? HKObjectQueryNoLimit,
                    unit: unit
                )
                let result = try await core?.getQuantitySamples(sampleType, parameters)
                let json = try JSONEncoder().encode(result)
                resolve(String(data: json, encoding: .utf8))
            } catch {
                reject("getQuantitySamples", error.localizedDescription, error)
            }
        }
    }
    
    @objc
    func getQuantitySamplesAggregation(_ query: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                guard
                    let unit = (query["unit"] as? String)?.hkUnit,
                    let type = query["type"] as? String,
                    let sampleType: QuantityType = .init(rawValue: type),
                    let startDate = (query["startDate"] as? String)?.fromIsoStringToDate(),
                    let endDate = (query["endDate"] as? String)?.fromIsoStringToDate(),
                    let optionStr = (query["option"] as? String),
                    let option: AggregationOptions = .init(rawValue: optionStr)
                else {
                        reject("getQuantitySamplesAggregation", "Invalid parameters.", nil)
                        return
                }

                let intervalStr = query["interval"] as? String ?? ""
                let interval = AggregationInterval(rawValue: intervalStr) ?? .day
                let anchorDate = (query["anchorDate"] as? String)?.fromIsoStringToDate() ?? Calendar(identifier: .gregorian).startOfDay(for: Date())

                let parameters = AggregationQuantityQuery(
                    startDate: startDate,
                    endDate: endDate,
                    interval: interval.dateComponents,
                    anchorDate: anchorDate,
                    unit: unit,
                    aggregationOption: option,
                    isUserEntered: query["isUserEntered"] as? Bool
                )
                let result = try await core?.getQuantitySamplesAggregation(sampleType, parameters)
                let json = try JSONEncoder().encode(result)
                resolve(String(data: json, encoding: .utf8))
            } catch {
                reject("getQuantitySamplesAggregation", error.localizedDescription, error)
                return
            }
        }
    }
    
    @objc
    func saveQuantitySample(_ type: String, sample: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        Task {
            do {
                guard
                    let sampleType: QuantityType = .init(rawValue: type),
                    let value = sample["value"] as? Double,
                    let unit = (sample["unit"] as? String)?.hkUnit,
                    let startDate = (sample["startDate"] as? String)?.fromIsoStringToDate(),
                    let endDate = (sample["endDate"] as? String)?.fromIsoStringToDate()
                else {
                    reject("saveQuantitySample", "Invalid parameters.", nil)
                    return
                }
                try await core?.saveQuantitySample(
                    .init(
                        type: sampleType,
                        value: value,
                        unit: unit,
                        startDate: startDate,
                        endDate: endDate
                    )
                )
            } catch {
                reject("saveQuantitySample", error.localizedDescription, error)
                return
            }
        }
    }
}
