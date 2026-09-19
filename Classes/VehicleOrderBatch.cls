global class VehicleOrderBatch implements Database.Batchable<SObject> {

    // Start method
    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, Status__c, Vehicle__c
            FROM Vehicle_Order__c
            WHERE Status__c = 'Pending'
        ]);
    }


    // Execute method
    global void execute(
        Database.BatchableContext bc,
        List<SObject> scope
    ) {

        List<Vehicle_Order__c> orderList =
            (List<Vehicle_Order__c>) scope;

        Set<Id> vehicleIds = new Set<Id>();

        // Collect Vehicle IDs
        for (Vehicle_Order__c order : orderList) {

            if (order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
            }
        }

        if (vehicleIds.isEmpty()) {
            return;
        }


        // Get vehicle stock
        Map<Id, Vehicle__c> vehicleStockMap =
            new Map<Id, Vehicle__c>([
                SELECT Id, Stock__c
                FROM Vehicle__c
                WHERE Id IN :vehicleIds
        ]);


        List<Vehicle_Order__c> ordersToUpdate =
            new List<Vehicle_Order__c>();

        List<Vehicle__c> vehiclesToUpdate =
            new List<Vehicle__c>();


        // Check stock
        for (Vehicle_Order__c order : orderList) {

            if (vehicleStockMap.containsKey(order.Vehicle__c)) {

                Vehicle__c vehicle =
                    vehicleStockMap.get(order.Vehicle__c);


                if (vehicle.Stock__c > 0) {

                    // Confirm the order
                    order.Status__c = 'Confirmed';

                    // Reduce stock
                    vehicle.Stock__c -= 1;

                    ordersToUpdate.add(order);
                    vehiclesToUpdate.add(vehicle);
                }
            }
        }


        // Update orders
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }


        // Update vehicles
        if (!vehiclesToUpdate.isEmpty()) {
            update vehiclesToUpdate;
        }
    }


    // Finish method
    global void finish(Database.BatchableContext bc) {

        System.debug('Vehicle order batch job completed.');
    }
}