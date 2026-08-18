@isTest
private class ApplicationWebhookTest {

    private static RestRequest buildRequest(String jsonBody) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/external/applications';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        return req;
    }

    @isTest
    static void testHandlePost_createsOpportunity_whenAccountMatches() {
        Account acc = new Account(Name = 'Acme Corp', Federal_Tax_Id__c = 'BG123456789');
        insert acc;

        String json =
            '{"companyName":"Acme Corp","federalTaxId":"BG123456789",' +
            '"contact":{"firstName":"Ivan","lastName":"Ivanov","email":"ivan@example.com","phone":"+359888123456"},' +
            '"annualRevenue":500000}';

        RestContext.request = buildRequest(json);
        RestContext.response = new RestResponse();

        Test.startTest();
        WebhookResponse response = ApplicationWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertEquals('Opportunity', response.recordType);
        System.assertEquals(200, RestContext.response.statusCode);

        Opportunity opp = [SELECT Application_Source__c FROM Opportunity WHERE Id = :response.recordId];
        System.assertEquals('Webhook', opp.Application_Source__c);
    }

    @isTest
    static void testHandlePost_createsLead_whenNoAccountMatches() {
        String json =
            '{"companyName":"New Co","federalTaxId":"NO-MATCH",' +
            '"contact":{"firstName":"Jon","lastName":"Snow","email":"jon@example.com","phone":"123"}}';

        RestContext.request = buildRequest(json);
        RestContext.response = new RestResponse();

        Test.startTest();
        WebhookResponse response = ApplicationWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertEquals('Lead', response.recordType);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    @isTest
    static void testHandlePost_blankBody_returnsError() {
        RestContext.request = buildRequest('');
        RestContext.response = new RestResponse();

        Test.startTest();
        WebhookResponse response = ApplicationWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testHandlePost_malformedJson_returnsError() {
        RestContext.request = buildRequest('{not valid json');
        RestContext.response = new RestResponse();

        Test.startTest();
        WebhookResponse response = ApplicationWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testHandlePost_missingRequiredField_returnsValidationError() {
        String json = '{"contact":{"firstName":"Jon","lastName":"Snow"}}';

        RestContext.request = buildRequest(json);
        RestContext.response = new RestResponse();

        Test.startTest();
        WebhookResponse response = ApplicationWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('Company Name is required.', response.message);
    }
}
