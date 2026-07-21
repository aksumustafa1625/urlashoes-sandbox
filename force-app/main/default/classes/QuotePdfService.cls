/**
 * @description Backend service for the Quote PDF LWC: reads Quote data, computes next version,
 *  uploads PDF as Attachment.
 * @author      Mustafa Aksu
 * @date        2026-05-30
 */
public with sharing class QuotePdfService {

    // PDF mime type used for filtering attachments and tagging uploads
    private static final String PDF_CONTENT_TYPE = 'application/pdf';

    // Regex matching the trailing _v<N>.pdf suffix in attachment file names
    private static final Pattern VERSION_PATTERN = Pattern.compile('_v(\\d+)\\.pdf$');

    // Returns the Quote header data plus its line items - NOT cacheable so the LWC always gets fresh data right before PDF generation
    @AuraEnabled
    public static QuoteWrapper getQuoteData(Id quoteId) {
        Quote q = [
            SELECT Id, Name, QuoteNumber, ExpirationDate, CreatedDate,
                   BillingName, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Phone, Email,
                   Subtotal, Discount, Tax, GrandTotal,
                   AccountId, Account.Name,
                   OpportunityId, Opportunity.Name
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        // Product2.Name is included so the PDF can fall back to it when Description is blank
        List<QuoteLineItem> lines = [
            SELECT Id, Description, Quantity, UnitPrice, TotalPrice,
                   Product2Id, Product2.Name
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];
        return new QuoteWrapper(q, lines);
    }

    // Returns a compact string that changes whenever the Quote header or its line items change.
    // The LWC polls this every few seconds to detect saves that LDS getRecord might miss (eg. line item rollups).
    @AuraEnabled
    public static String getQuoteChangeSignature(Id quoteId) {
        Quote q = [
            SELECT LastModifiedDate, Subtotal, Discount, Tax, TotalPrice, GrandTotal
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        Integer lineCount = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId];
        return ''
            + q.LastModifiedDate.getTime() + '|'
            + q.Subtotal + '|'
            + q.Discount + '|'
            + q.Tax + '|'
            + q.TotalPrice + '|'
            + q.GrandTotal + '|'
            + lineCount;
    }

    // Returns true if at least one PDF attachment already exists on the Quote
    @AuraEnabled(cacheable=true)
    public static Boolean hasAnyPdf(Id quoteId) {
        return ![
            SELECT Id FROM Attachment
            WHERE ParentId = :quoteId AND ContentType = :PDF_CONTENT_TYPE
            LIMIT 1
        ].isEmpty();
    }

    // Returns the next available version number based on existing _v<N>.pdf attachments
    @AuraEnabled
    public static Integer getNextVersionNumber(Id quoteId) {
        Integer maxVersion = 0;
        for (Attachment a : [
            SELECT Name FROM Attachment
            WHERE ParentId = :quoteId AND ContentType = :PDF_CONTENT_TYPE
        ]) {
            Integer v = parseVersion(a.Name);
            if (v > maxVersion) {
                maxVersion = v;
            }
        }
        return maxVersion + 1;
    }

    // Inserts a PDF Attachment on the Quote from a base64-encoded body sent by the LWC
    @AuraEnabled
    public static Id uploadPdf(Id quoteId, String base64Body, String fileName) {
        // Decode the LWC payload back into binary and create the Attachment
        Attachment a = new Attachment(
            ParentId    = quoteId,
            Name        = fileName,
            Body        = EncodingUtil.base64Decode(base64Body),
            ContentType = PDF_CONTENT_TYPE
        );
        insert a;
        return a.Id;
    }

    // Extracts the integer N from a file name like "Quote-0001_v3.pdf", returns 0 if no match
    private static Integer parseVersion(String fileName) {
        if (String.isBlank(fileName)) {
            return 0;
        }
        Matcher m = VERSION_PATTERN.matcher(fileName);
        return m.find() ? Integer.valueOf(m.group(1)) : 0;
    }

    // DTO returned to the LWC so the component can render header and line item data
    public class QuoteWrapper {
        @AuraEnabled public Quote quote;
        @AuraEnabled public List<QuoteLineItem> lines;
        public QuoteWrapper(Quote q, List<QuoteLineItem> l) {
            this.quote = q;
            this.lines = l;
        }
    }
}
