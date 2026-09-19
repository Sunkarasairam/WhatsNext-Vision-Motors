public class VehicleOrderTriggerHandler {
   public static void handleTrigger(
    List<Vehicle_Order__c> newOrders,
    Map<Id, Vehicle_Order__c> oldOrders,
    Boolean isBefore,
    Boolean isAfter,
    Boolean isInsert,
    Boolean isUpdate
) {

    // BEFORE INSERT / BEFORE UPDATE
    if (isBefore && (isInsert || isUpdate)) {
        preventOrderIfOutOfStock(newOrders);
    }

    // AFTER INSERT / AFTER UPDATE
    if (isAfter && (isInsert || isUpdate)) {
        updateStockOnOrderPlacement(newOrders, oldOrders, isInsert);
    }
}


// Method to prevent orders when the vehicle is out of stock
private static void preventOrderIfOutOfStock(
    List<Vehicle_Order__c> orders
) {

    Set<Id> vehicleIds = new Set<Id>();

    // Collect Vehicle IDs
    for (Vehicle_Order__c order : orders) {
        if (order.Vehicle__c != null) {
            vehicleIds.add(order.Vehicle__c);
        }
    }

    if (vehicleIds.isEmpty()) {
        return;
    }

    // Get vehicle stock
    Map<Id, Vehicle__c> vehicleStockMap = new Map<Id, Vehicle__c>(
        [
            SELECT Id, Stock__c
            FROM Vehicle__c
            WHERE Id IN :vehicleIds
        ]
    );

    // Validate stock
    for (Vehicle_Order__c order : orders) {

        if (order.Vehicle__c != null &&
            vehicleStockMap.containsKey(order.Vehicle__c)) {

            Vehicle__c vehicle = vehicleStockMap.get(order.Vehicle__c);

            if (vehicle.Stock__c <= 0) {
                order.addError(
                    'This vehicle is out of stock. Order cannot be placed.'
                );
            }
        }
    }
}


// Method to update vehicle stock when an order is confirmed
private static void updateStockOnOrderPlacement(
    List<Vehicle_Order__c> orders,
    Map<Id, Vehicle_Order__c> oldOrders,
    Boolean isInsert
) {

    Set<Id> vehicleIds = new Set<Id>();

    // Collect Vehicle IDs only when order becomes Confirmed
    for (Vehicle_Order__c order : orders) {

        Boolean shouldUpdateStock = false;

        // New order
        if (isInsert && order.Status__c == 'Confirmed') {
            shouldUpdateStock = true;
        }

        // Existing order changes to Confirmed
        if (!isInsert &&
            order.Status__c == 'Confirmed' &&
            oldOrders.containsKey(order.Id) &&
            oldOrders.get(order.Id).Status__c != 'Confirmed') {

            shouldUpdateStock = true;
        }

        if (shouldUpdateStock && order.Vehicle__c != null) {
            vehicleIds.add(order.Vehicle__c);
        }
    }

    if (vehicleIds.isEmpty()) {
        return;
    }

    // Get vehicles
    Map<Id, Vehicle__c> vehicleStockMap = new Map<Id, Vehicle__c>(
        [
            SELECT Id, Stock__c
            FROM Vehicle__c
            WHERE Id IN :vehicleIds
        ]
    );

    List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();

    // Reduce stock
    for (Vehicle_Order__c order : orders) {

        Boolean shouldUpdateStock = false;

        if (isInsert && order.Status__c == 'Confirmed') {
            shouldUpdateStock = true;
        }

        if (!isInsert &&
            order.Status__c == 'Confirmed' &&
            oldOrders.containsKey(order.Id) &&
            oldOrders.get(order.Id).Status__c != 'Confirmed') {

            shouldUpdateStock = true;
        }

        if (shouldUpdateStock &&
            order.Vehicle__c != null &&
            vehicleStockMap.containsKey(order.Vehicle__c)) {

            Vehicle__c vehicle = vehicleStockMap.get(order.Vehicle__c);

            if (vehicle.Stock__c > 0) {
                vehicle.Stock__c -= 1;
                vehiclesToUpdate.add(vehicle);
            }
        }
    }

    // Update vehicle stock
    if (!vehiclesToUpdate.isEmpty()) {
        update vehiclesToUpdate;
    }
}
}