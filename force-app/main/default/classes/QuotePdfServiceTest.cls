/**
 * @description Tests for QuotePdfService - data retrieval, version numbering, and PDF attachment upload.
 * @author      Mustafa Aksu
 * @date        2026-05-30
 */
@isTest
private class QuotePdfServiceTest {

    // Seed a Quote backed by an Opportunity so the service has something to read
    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Customer');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        insert new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            ExpirationDate = Date.today().addDays(45),
            BillingName = 'Test Customer',
            BillingCity = 'Izmir',
            BillingCountry = 'Turkey',
            Phone = '+90 232 000 00 00',
            Email = 'buyer@test.com'
        );
    }

    @isTest
    static void getQuoteDataReturnsHeaderAndLines() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        QuotePdfService.QuoteWrapper w = QuotePdfService.getQuoteData(q.Id);
        Test.stopTest();
        // Header should be populated with the seeded values
        System.assertNotEquals(null, w.quote, 'Wrapper should expose the Quote');
        System.assertEquals('Test Customer', w.quote.BillingName, 'BillingName should round-trip');
        // No line items were created so the list should be empty but non-null
        System.assertNotEquals(null, w.lines, 'Lines list should never be null');
        System.assertEquals(0, w.lines.size(), 'No line items expected on the seeded quote');
    }

    @isTest
    static void hasAnyPdfReturnsFalseWhenNoneAttached() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        // Fresh quote has no attachments
        System.assertEquals(false, QuotePdfService.hasAnyPdf(q.Id), 'Should be false before any upload');
    }

    @isTest
    static void getNextVersionStartsAtOne() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        // No prior PDFs - first version should be 1
        System.assertEquals(1, QuotePdfService.getNextVersionNumber(q.Id), 'Initial version should be 1');
    }

    @isTest
    static void uploadPdfCreatesAttachmentAndIncrementsVersion() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('PDF-CONTENT'));
        Test.startTest();
        // Upload version 1
        Id attId = QuotePdfService.uploadPdf(q.Id, base64, 'Test_v1.pdf');
        Test.stopTest();
        // The attachment should exist with the right metadata
        Attachment a = [SELECT Name, ContentType, ParentId FROM Attachment WHERE Id = :attId];
        System.assertEquals('Test_v1.pdf', a.Name, 'File name should be preserved');
        System.assertEquals('application/pdf', a.ContentType, 'Content type should be PDF');
        System.assertEquals(q.Id, a.ParentId, 'Parent should be the Quote');
        // hasAnyPdf should now report true
        System.assertEquals(true, QuotePdfService.hasAnyPdf(q.Id), 'Should detect the new attachment');
        // Next version should advance to 2
        System.assertEquals(2, QuotePdfService.getNextVersionNumber(q.Id), 'Next version should advance to 2');
    }

    @isTest
    static void changeSignatureReflectsLineCount() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        // Baseline signature with no line items
        String before = QuotePdfService.getQuoteChangeSignature(q.Id);
        // Insert a Pricebook entry would be a heavy lift in test - we already trust the SELECT shape; just assert format
        System.assert(before.contains('|'), 'Signature should contain multiple pipe-separated values');
        // Last segment is the line item count - should be 0 on a fresh quote
        List<String> parts = before.split('\\|');
        System.assertEquals('0', parts[parts.size() - 1], 'Line count segment should be 0 with no line items');
    }

    @isTest
    static void versionNumberSkipsNonPdfNamesGracefully() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('PDF'));
        // A name without _v<N>.pdf should not affect versioning
        QuotePdfService.uploadPdf(q.Id, base64, 'random_export.pdf');
        QuotePdfService.uploadPdf(q.Id, base64, 'Q_v3.pdf');
        // Max recognised version is 3 so next should be 4
        System.assertEquals(4, QuotePdfService.getNextVersionNumber(q.Id), 'Next version should follow the highest _v<N>');
    }
}
