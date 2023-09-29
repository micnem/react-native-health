import Foundation
import HealthKit

public extension HealthKitCore {
    func getQuantitySamplesStatistics(
        _ type: QuantityType,
        _ queryParameters: StatisticsQuantityQuery
    ) async throws -> [QuantitySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let sampleType = type.type as! HKQuantityType
            let query = HKStatisticsCollectionQuery(
                quantityType: sampleType,
                quantitySamplePredicate: queryParameters.predicate,
                options: queryParameters.statisticsOption.toHKType,
                anchorDate: queryParameters.anchorDate,
                intervalComponents: queryParameters.interval
            )

            query.initialResultsHandler = { _, results, error in
                switchAndContinue(continuation: continuation, value: results, error: error) { collection in
                    return Self.enumerateStatistics(
                        collection: collection,
                        queryParameters
                    )
                }
            }
            healthStore.execute(query)
        }
    }

    static func enumerateStatistics(
        collection: HKStatisticsCollection,
        _ queryParameters: StatisticsQuantityQuery
    ) -> [QuantitySample] {
        var samples: [QuantitySample] = []
        let enumerationFunction = queryParameters.statisticsOption.enumeration
        collection.enumerateStatistics(from: queryParameters.startDate!, to: queryParameters.endDate!) { statistics, stop in
            enumerationFunction(statistics).map {
                samples.append(.init($0, queryParameters.unit, statistics.startDate, statistics.endDate))
            }
        }
        return samples
    }

    func getQuantitySamples(_ type: QuantityType, _ queryParameters: QuantityQuery) async throws -> [QuantitySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let sampleType = type.type as! HKQuantityType
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: queryParameters.predicate,
                limit: queryParameters.limit,
                sortDescriptors: [sortDescriptor])
            { (_, samples, error) in
                guard error == nil else {
                    continuation.resume(throwing: error!)
                    return
                }
                let quantitySamples = (samples as! [HKQuantitySample]).map {
                    QuantitySample($0, queryParameters.unit)
                }
                continuation.resume(returning: quantitySamples)
            }
            healthStore.execute(query)
        }
    }

    func saveQuantitySample(_ sample: QuantitySampleInsert) async throws {
        let type = sample.type.type as! HKQuantityType
        let unit = sample.unit
        let quantity = HKQuantity(unit: unit, doubleValue: sample.value)
        try await self.healthStore.save(
            HKQuantitySample(type: type, quantity: quantity, start: sample.startDate, end: sample.endDate, metadata: sample.metadata)
        )
    }
}