/**
 * Parses the nested webhook JSON payload, flattens it into the same
 * ApplicationDTO used by the LWC, and delegates to
 * ApplicationProcessingService so both channels share identical business logic.
 */
@RestResource(urlMapping='/external/applications')
global with sharing class ApplicationWebhook {

    @HttpPost
    global static WebhookResponse handlePost() {
        RestResponse response = RestContext.response;

        try {
            String body = RestContext.request.requestBody != null
                ? RestContext.request.requestBody.toString()
                : null;

            if (String.isBlank(body)) {
                response.statusCode = 400;
                return new WebhookResponse(false, null, null, 'Request body is required.');
            }

            WebhookPayload payload = (WebhookPayload) JSON.deserialize(body, WebhookPayload.class);
            ApplicationDTO dto = toApplicationDTO(payload);
            dto.applicationSource = 'Webhook';

            ApplicationResult result = ApplicationProcessingService.processApplication(dto);

            response.statusCode = result.success ? 200 : 400;
            return new WebhookResponse(result.success, result.recordType, result.recordId, result.message);
        } catch (Exception e) {
            response.statusCode = 400;
            return new WebhookResponse(false, null, null, 'Invalid request: ' + e.getMessage());
        }
    }

    private static ApplicationDTO toApplicationDTO(WebhookPayload payload) {
        ApplicationDTO dto = new ApplicationDTO();
        dto.companyName = payload?.companyName;
        dto.federalTaxId = payload?.federalTaxId;
        dto.annualRevenue = payload?.annualRevenue;

        if (payload?.contact != null) {
            dto.firstName = payload.contact.firstName;
            dto.lastName = payload.contact.lastName;
            dto.email = payload.contact.email;
            dto.phone = payload.contact.phone;
        }

        return dto;
    }

    private class WebhookPayload {
        String companyName;
        String federalTaxId;
        ContactPayload contact;
        Decimal annualRevenue;
    }

    private class ContactPayload {
        String firstName;
        String lastName;
        String email;
        String phone;
    }
}
