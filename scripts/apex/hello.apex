

ApplicationDTO dto = new ApplicationDTO();
dto.companyName = 'Cloudsquare';
dto.federalTaxId = 'BG123456789';
dto.firstName = 'test';
dto.lastName = 'testing';
dto.email = 'test@example.com';
dto.phone = '+359888123456';
dto.annualRevenue = 500000;
dto.applicationSource = 'Community';

ApplicationResult result = ApplicationProcessingService.processApplication(dto);
System.debug('success=' + result.success + ' recordType=' + result.recordType + ' recordId=' + result.recordId + ' message=' + result.message);
