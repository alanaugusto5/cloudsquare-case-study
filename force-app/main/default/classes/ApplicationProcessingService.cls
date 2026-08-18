/**
 * Shared business logic used by both the applicationForm LWC via
 * ApplicationFormController and the public webhook ApplicationWebhook
 *
 * All SOQL andDML runs with explicit USER_MODE access level enforcement, so
 * the site Guest User can only do what the Application_Portal_Guest_Access
 * permission set grants read Account, create Lead, and create Opportunity, on exactly the fields
 * this service touches, the class stays "with sharing" for defense in depth
 * record visibility for the Account match comes from that granted "View All"
 * permission, not from a class level sharing bypass.
 */
public with sharing class ApplicationProcessingService {

    private static final String STAGE_NAME = 'Prospecting';
    private static final Integer CLOSE_DATE_OFFSET_DAYS = 30;
    private static final String RECORD_TYPE_LEAD = 'Lead';
    private static final String RECORD_TYPE_OPPORTUNITY = 'Opportunity';

    public static ApplicationResult processApplication(ApplicationDTO app) {
        String validationError = validate(app);
        if (validationError != null) {
            return new ApplicationResult(false, null, null, validationError);
        }

        try {
            Account matchedAccount = findMatchingAccount(app);

            if (matchedAccount != null) {
                Opportunity opp = createOpportunity(app, matchedAccount.Id);
                return new ApplicationResult(true, RECORD_TYPE_OPPORTUNITY, opp.Id, 'Application processed successfully');
            }

            Lead newLead = createLead(app);
            return new ApplicationResult(true, RECORD_TYPE_LEAD, newLead.Id, 'Application processed successfully');
        } catch (DmlException e) {
            return new ApplicationResult(false, null, null, 'Unable to save application: ' + e.getDmlMessage(0));
        } catch (System.NoAccessException e) {
            return new ApplicationResult(false, null, null, 'Insufficient access to process the application.');
        } catch (Exception e) {
            return new ApplicationResult(false, null, null, 'Unexpected error: ' + e.getMessage());
        }
    }

    private static String validate(ApplicationDTO app) {
        if (app == null) {
            return 'Application data is required.';
        }
        if (String.isBlank(app.companyName)) {
            return 'Company Name is required.';
        }
        if (String.isBlank(app.lastName)) {
            return 'Contact Last Name is required.';
        }
        if (String.isBlank(app.applicationSource)) {
            return 'Application Source is required.';
        }
        return null;
    }

    private static Account findMatchingAccount(ApplicationDTO app) {
        List<Account> matches;
        if (String.isNotBlank(app.federalTaxId)) {
            matches = [
                SELECT Id, Name
                FROM Account
                WHERE Federal_Tax_Id__c = :app.federalTaxId
                WITH USER_MODE
                LIMIT 1
            ];
        } else {
            matches = [
                SELECT Id, Name
                FROM Account
                WHERE Name = :app.companyName
                WITH USER_MODE
                LIMIT 1
            ];
        }
        return matches.isEmpty() ? null : matches[0];
    }

    private static Opportunity createOpportunity(ApplicationDTO app, Id accountId) {
        Opportunity opp = new Opportunity(
            Name = app.companyName + ' - New Application',
            StageName = STAGE_NAME,
            CloseDate = Date.today().addDays(CLOSE_DATE_OFFSET_DAYS),
            AccountId = accountId,
            Application_Source__c = app.applicationSource
        );
        insert as user opp;
        return opp;
    }

    private static Lead createLead(ApplicationDTO app) {
        Lead newLead = new Lead(
            FirstName = app.firstName,
            LastName = app.lastName,
            Company = app.companyName,
            Email = app.email,
            Phone = app.phone,
            Federal_Tax_Id__c = app.federalTaxId,
            Application_Source__c = app.applicationSource
        );
        if (app.annualRevenue != null) {
            newLead.AnnualRevenue = app.annualRevenue;
        }
        insert as user newLead;
        return newLead;
    }
}
