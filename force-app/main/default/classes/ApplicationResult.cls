/**
 * Result returned by ApplicationProcessingService.processApplication and,
 * unchanged, by ApplicationFormController.submitApplication.
 */
public class ApplicationResult {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String recordType;
    @AuraEnabled public Id recordId;
    @AuraEnabled public String message;

    public ApplicationResult(Boolean success, String recordType, Id recordId, String message) {
        this.success = success;
        this.recordType = recordType;
        this.recordId = recordId;
        this.message = message;
    }
}
