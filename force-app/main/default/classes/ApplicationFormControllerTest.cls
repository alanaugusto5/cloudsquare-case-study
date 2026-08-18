@isTest
private class ApplicationFormControllerTest {

    private static ApplicationDTO buildDto() {
        ApplicationDTO dto = new ApplicationDTO();
        dto.companyName = 'Community Test Co';
        dto.federalTaxId = 'CT-000';
        dto.firstName = 'Jane';
        dto.lastName = 'Doe';
        dto.email = 'jane@example.com';
        dto.phone = '+15551234567';
        dto.annualRevenue = 100000;
        dto.applicationSource = 'Webhook';
        return dto;
    }

    @isTest
    static void testSubmitApplication_createsLead_andForcesCommunitySource() {
        ApplicationDTO dto = buildDto();

        Test.startTest();
        ApplicationResult result = ApplicationFormController.submitApplication(dto);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Lead', result.recordType);

        Lead createdLead = [SELECT Application_Source__c FROM Lead WHERE Id = :result.recordId];
        System.assertEquals(
            'Community',
            createdLead.Application_Source__c,
            'Controller must force applicationSource to Community regardless of client input'
        );
    }

    @isTest
    static void testSubmitApplication_nullInput_throwsAuraHandledException() {
        Boolean exceptionThrown = false;
        String message;

        Test.startTest();
        try {
            ApplicationFormController.submitApplication(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
        System.assertEquals('Application data is required.', message);
    }
}
