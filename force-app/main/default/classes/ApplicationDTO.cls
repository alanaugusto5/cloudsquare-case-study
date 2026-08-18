/**
 * Input contract for a partner application.
 * Populated directly from the applicationForm LWC, or mapped from the
 * nested webhook JSON payload by ApplicationWebhook before being handed
 * to ApplicationProcessingService. applicationSource is set server-side
 * by each entry point.
 */
public class ApplicationDTO {
    @AuraEnabled public String companyName;
    @AuraEnabled public String federalTaxId;
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public String email;
    @AuraEnabled public String phone;
    @AuraEnabled public Decimal annualRevenue;
    @AuraEnabled public String applicationSource;
}
