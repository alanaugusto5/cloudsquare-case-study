/**
 * JSON response contract for the ApplicationWebhook REST endpoint.
 * Declared global because it is the return type of a global @HttpPost method.
 */
global class WebhookResponse {
    global Boolean success;
    global String recordType;
    global String recordId;
    global String message;

    global WebhookResponse(Boolean success, String recordType, String recordId, String message) {
        this.success = success;
        this.recordType = recordType;
        this.recordId = recordId;
        this.message = message;
    }
}
