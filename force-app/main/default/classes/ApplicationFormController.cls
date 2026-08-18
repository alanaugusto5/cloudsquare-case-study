/**
 * entry point for the public applicationForm LWC.
 * applicationSource is forced server side so client input can never spoof it
 */
public with sharing class ApplicationFormController {

    @AuraEnabled
    public static ApplicationResult submitApplication(ApplicationDTO input) {
        if (input == null) {
            throw wrapAsAuraHandled('Application data is required.');
        }

        input.applicationSource = 'Community';

        try {
            return ApplicationProcessingService.processApplication(input);
        } catch (Exception e) {
            throw wrapAsAuraHandled('Unable to submit application: ' + e.getMessage());
        }
    }

    /**
     * AuraHandledException masks getMessage() with a generic string unless
     * setMessage() is called explicitly, both for the client and in tests.
     */
    private static AuraHandledException wrapAsAuraHandled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
