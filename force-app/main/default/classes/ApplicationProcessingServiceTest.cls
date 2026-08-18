@isTest
private class ApplicationProcessingServiceTest {

    private static ApplicationDTO buildDto(String companyName, String federalTaxId, String source) {
        ApplicationDTO dto = new ApplicationDTO();
        dto.companyName = companyName;
        dto.federalTaxId = federalTaxId;
        dto.firstName = 'Ivan';
        dto.lastName = 'Ivanov';
        dto.email = 'ivan@example.com';
        dto.phone = '+359888123456';
        dto.annualRevenue = 500000;
        dto.applicationSource = source;
        return dto;
    }

    @isTest
    static void testNoAccountMatch_createsLead() {
        ApplicationDTO dto = buildDto('Unmatched Company Inc', 'ZZ-000-NOMATCH', 'Community');

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected a successful result');
        System.assertEquals('Lead', result.recordType, 'Expected a Lead to be created when no Account matches');
        System.assertNotEquals(null, result.recordId, 'Expected a record Id to be returned');

        Lead createdLead = [
            SELECT FirstName, LastName, Company, Email, Phone, Federal_Tax_Id__c, Application_Source__c
            FROM Lead
            WHERE Id = :result.recordId
        ];
        System.assertEquals('Unmatched Company Inc', createdLead.Company);
        System.assertEquals('Community', createdLead.Application_Source__c);
        System.assertEquals('ZZ-000-NOMATCH', createdLead.Federal_Tax_Id__c);
    }

    @isTest
    static void testAccountMatchByTaxId_createsOpportunity() {
        Account acc = new Account(Name = 'Acme Corp', Federal_Tax_Id__c = 'BG123456789');
        insert acc;

        ApplicationDTO dto = buildDto('Acme Corp', 'BG123456789', 'Webhook');

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected a successful result');
        System.assertEquals('Opportunity', result.recordType, 'Expected an Opportunity when Tax ID matches an Account');

        Opportunity createdOpp = [
            SELECT Name, StageName, CloseDate, AccountId, Application_Source__c
            FROM Opportunity
            WHERE Id = :result.recordId
        ];
        System.assertEquals(acc.Id, createdOpp.AccountId);
        System.assertEquals('Acme Corp - New Application', createdOpp.Name);
        System.assertEquals('Prospecting', createdOpp.StageName);
        System.assertEquals(Date.today().addDays(30), createdOpp.CloseDate);
        System.assertEquals('Webhook', createdOpp.Application_Source__c);
    }

    @isTest
    static void testAccountMatchByName_whenTaxIdBlank_createsOpportunity() {
        Account acc = new Account(Name = 'Globex Corporation');
        insert acc;

        ApplicationDTO dto = buildDto('Globex Corporation', null, 'Community');

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected a successful result');
        System.assertEquals('Opportunity', result.recordType, 'Expected an Opportunity when Name matches an Account and Tax ID is blank');

        Opportunity createdOpp = [SELECT AccountId FROM Opportunity WHERE Id = :result.recordId];
        System.assertEquals(acc.Id, createdOpp.AccountId);
    }

    @isTest
    static void testBlankTaxIdDoesNotFallBackToTaxIdMatch() {
        Account acc = new Account(Name = 'Different Name Ltd', Federal_Tax_Id__c = 'SHOULD-NOT-MATCH');
        insert acc;

        ApplicationDTO dto = buildDto('Some Other Company', null, 'Community');

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals('Lead', result.recordType, 'A blank Tax ID must only trigger a Name match, not fall back to any Tax ID');
    }

    @isTest
    static void testApplicationSource_webhookVsCommunity() {
        Account acc = new Account(Name = 'Initech', Federal_Tax_Id__c = 'IT-999');
        insert acc;

        ApplicationDTO webhookDto = buildDto('Initech', 'IT-999', 'Webhook');
        ApplicationDTO communityDto = buildDto('Unmatched Co', 'NO-MATCH-123', 'Community');

        Test.startTest();
        ApplicationResult webhookResult = ApplicationProcessingService.processApplication(webhookDto);
        ApplicationResult communityResult = ApplicationProcessingService.processApplication(communityDto);
        Test.stopTest();

        Opportunity opp = [SELECT Application_Source__c FROM Opportunity WHERE Id = :webhookResult.recordId];
        Lead lead = [SELECT Application_Source__c FROM Lead WHERE Id = :communityResult.recordId];

        System.assertEquals('Webhook', opp.Application_Source__c);
        System.assertEquals('Community', lead.Application_Source__c);
    }

    @isTest
    static void testMissingCompanyName_returnsFailureWithoutCreatingRecords() {
        ApplicationDTO dto = buildDto(null, null, 'Community');

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(null, result.recordId);
        System.assertEquals('Company Name is required.', result.message);
    }

    @isTest
    static void testMissingLastName_returnsFailure() {
        ApplicationDTO dto = buildDto('Some Company', null, 'Community');
        dto.lastName = null;

        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(dto);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Contact Last Name is required.', result.message);
    }

    @isTest
    static void testNullInput_returnsFailure() {
        Test.startTest();
        ApplicationResult result = ApplicationProcessingService.processApplication(null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Application data is required.', result.message);
    }
}
