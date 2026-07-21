/**
 * @description Generates a styled Quote PDF client-side via jsPDF and uploads it as a versioned Attachment.
 *              Reactive: auto-runs once on first load (v1) and again on every Quote save (v2, v3, ...) by
 *              watching the record via LDS getRecord.
 * @author      Mustafa Aksu
 * @date        2026-05-30
 */
import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPdfResource from '@salesforce/resourceUrl/jsPDF';
import getQuoteData from '@salesforce/apex/QuotePdfService.getQuoteData';
import getQuoteChangeSignature from '@salesforce/apex/QuotePdfService.getQuoteChangeSignature';
import getNextVersionNumber from '@salesforce/apex/QuotePdfService.getNextVersionNumber';
import uploadPdf from '@salesforce/apex/QuotePdfService.uploadPdf';

// How often to poll the signature - covers cases where LDS does not auto-refresh the page (e.g. line item rollups)
const POLL_INTERVAL_MS = 3000;

// Debounce window: collapse rapid successive saves into one regeneration
const REGEN_DEBOUNCE_MS = 1500;

export default class QuotePdfGenerator extends LightningElement {

    // Record Id passed in automatically when placed on a Quote record page
    @api recordId;

    // jsPDF loaded flag - guards against running before the library is ready
    jsPdfReady = false;

    // True while a PDF is being generated and uploaded
    isGenerating = false;

    // Last successfully attached file name (shown to the user)
    lastFileName;

    // Last version number generated
    lastVersionNumber;

    // Any error message to display
    error;

    // Signature of the last tracked field values - new save = new signature = regenerate
    previousSignature;

    // Active debounce timer for the auto-regenerate scheduler
    regenerateTimeoutId;

    // Active polling interval that watches for record changes
    pollIntervalId;

    // True when nothing is happening yet - controls the helper text in the template
    get isIdle() {
        return !this.isGenerating && !this.lastFileName && !this.error;
    }

    // Load jsPDF on mount and start polling for record changes - no PDF on page open, only on saves
    async connectedCallback() {
        try {
            await loadScript(this, jsPdfResource);
            this.jsPdfReady = true;
            // Establish a baseline signature first so the very next change triggers a regenerate
            await this.pollOnce();
            this.pollIntervalId = setInterval(() => this.pollOnce(), POLL_INTERVAL_MS);
        } catch (e) {
            this.error = 'jsPDF library failed to load.';
        }
    }

    // Stop polling and clear the debounce timer when the component is removed
    disconnectedCallback() {
        if (this.pollIntervalId) {
            clearInterval(this.pollIntervalId);
        }
        if (this.regenerateTimeoutId) {
            clearTimeout(this.regenerateTimeoutId);
        }
    }

    // Polls the Quote signature on a short interval - catches header saves AND line item rollup updates
    async pollOnce() {
        if (this.isGenerating) {
            return;
        }
        try {
            const signature = await getQuoteChangeSignature({ quoteId: this.recordId });
            if (this.previousSignature && this.previousSignature !== signature) {
                // Change since last poll - schedule a debounced regeneration
                this.scheduleRegenerate();
            }
            this.previousSignature = signature;
        } catch (e) {
            // Silent fail - the next poll will retry
        }
    }

    // Debounces rapid save events into a single regeneration after the user finishes
    scheduleRegenerate() {
        if (this.regenerateTimeoutId) {
            clearTimeout(this.regenerateTimeoutId);
        }
        this.regenerateTimeoutId = setTimeout(async () => {
            try {
                await this.handleGenerate();
            } catch (e) {
                this.error = this.extractError(e);
            }
        }, REGEN_DEBOUNCE_MS);
    }

    // Builds the next version, uploads it, and shows a toast - also reachable from the button
    async handleGenerate() {
        if (!this.jsPdfReady || this.isGenerating) {
            return;
        }
        this.isGenerating = true;
        this.error = undefined;
        try {
            // Always fetch the freshest data right at the moment of generation
            const freshData = await getQuoteData({ quoteId: this.recordId });
            const version = await getNextVersionNumber({ quoteId: this.recordId });
            const base64 = this.buildPdfBase64(freshData, version);
            const baseName = freshData.quote.QuoteNumber || freshData.quote.Name || 'Quote';
            const fileName = `${baseName}_v${version}.pdf`;
            await uploadPdf({ quoteId: this.recordId, base64Body: base64, fileName: fileName });
            this.lastFileName = fileName;
            this.lastVersionNumber = version;
            this.dispatchEvent(new ShowToastEvent({
                title: 'PDF generated',
                message: `${fileName} attached to Notes & Attachments.`,
                variant: 'success'
            }));
        } catch (e) {
            this.error = this.extractError(e);
            this.dispatchEvent(new ShowToastEvent({
                title: 'PDF generation failed',
                message: this.error,
                variant: 'error'
            }));
        } finally {
            this.isGenerating = false;
        }
    }

    // Builds the styled PDF in memory and returns the base64 body (without the data-uri prefix)
    buildPdfBase64(data, version) {
        // jsPDF UMD exposes itself on window.jspdf
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF({ unit: 'pt', format: 'a4' });
        const q = data.quote;
        const lines = data.lines || [];

        // === Big "INVOICE" title on the left ===
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(46);
        doc.text('INVOICE', 40, 80);

        // === Company info block on the right ===
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text('URLA SHOES CORP.', 555, 50, { align: 'right' });
        doc.setFont('helvetica', 'normal');
        doc.text('Urla Commercial Zone, No: 35', 555, 65, { align: 'right' });
        doc.text('Izmir, Turkey', 555, 80, { align: 'right' });
        doc.text('accounting@urlashoes.com', 555, 95, { align: 'right' });
        doc.text('123-777-8888', 555, 110, { align: 'right' });

        // === Invoice meta row (number, due date, invoice date, prepared by) ===
        const dueDate = this.fmtDate(q.ExpirationDate);
        const invoiceDate = this.fmtDate((q.CreatedDate || '').substring(0, 10));
        this.labelValue(doc, 'Invoice #', q.QuoteNumber || '', 40, 160);
        this.labelValue(doc, 'Due Date:', dueDate, 350, 160);
        this.labelValue(doc, 'Invoice date:', invoiceDate, 40, 185);
        this.labelValue(doc, 'Prepared by:', 'Urla CRM Engine', 350, 185);

        // === Customer Details section with pink banner ===
        doc.setFillColor(252, 228, 236);
        doc.rect(40, 215, 515, 25, 'F');
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(11);
        doc.text('CUSTOMER DETAILS', 50, 232);

        // Customer fields with underline
        doc.setFontSize(10);
        const customerName = q.BillingName || (q.Account && q.Account.Name) || '';
        const address = [q.BillingStreet, q.BillingCity, q.BillingState, q.BillingPostalCode, q.BillingCountry]
            .filter(v => v).join(' ');
        let y = 265;
        this.fieldRow(doc, 'Name:', customerName, 40, y);
        y += 30;
        this.fieldRow(doc, 'Address:', address, 40, y);
        y += 30;
        this.twoFieldRow(doc, 'Phone:', q.Phone || '', 'Email:', q.Email || '', 40, y);

        // === Line items table header ===
        y += 30;
        doc.setFillColor(252, 228, 236);
        doc.rect(40, y, 515, 25, 'F');
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text('DESCRIPTION', 50, y + 17);
        doc.text('QTY', 325, y + 17, { align: 'right' });
        doc.text('PRICE', 440, y + 17, { align: 'right' });
        doc.text('TOTAL', 545, y + 17, { align: 'right' });

        // === Line item rows ===
        y += 25;
        doc.setFont('helvetica', 'normal');
        if (lines.length === 0) {
            // Empty placeholder rows to keep the layout consistent
            for (let i = 0; i < 5; i++) {
                doc.line(40, y, 555, y);
                y += 22;
            }
        } else {
            for (const ln of lines) {
                // Use the user-entered Description if present, otherwise fall back to the Product name
                const descText = ln.Description || (ln.Product2 && ln.Product2.Name) || '';
                const descLines = doc.splitTextToSize(descText, 275);
                let textHeight = descLines.length * 12 + 8;
                if (textHeight < 22) textHeight = 22;
                doc.text(descLines, 50, y + 14);
                doc.text(String(ln.Quantity != null ? ln.Quantity : ''), 325, y + 14, { align: 'right' });
                doc.text('$' + Number(ln.UnitPrice || 0).toFixed(2), 440, y + 14, { align: 'right' });
                doc.text('$' + Number(ln.TotalPrice || 0).toFixed(2), 545, y + 14, { align: 'right' });
                y += textHeight;
                doc.line(40, y, 555, y);
            }
        }

        // === Terms and conditions on the left + Totals on the right ===
        const totalsStartY = y + 25;
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.text('TERMS AND CONDITIONS:', 40, totalsStartY);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);
        const terms = 'This quotation is not a contract or invoice. It represents our best estimate of the total price for the goods and services described above. The customer will be billed upon accepting this quotation. Payment must be made in full prior to the delivery of goods and services. Please email or mail the signed quotation to the address listed above.';
        const wrapped = doc.splitTextToSize(terms, 280);
        doc.text(wrapped, 40, totalsStartY + 14);

        // Totals column
        doc.setFontSize(10);
        let ty = totalsStartY;
        this.totalRow(doc, 'SUBTOTAL', q.Subtotal, ty); ty += 22;
        this.totalRow(doc, 'DISCOUNT', q.Discount, ty); ty += 22;
        this.totalRow(doc, 'TAXES',    q.Tax,      ty); ty += 28;
        this.totalRow(doc, 'GRAND TOTAL', q.GrandTotal, ty);

        // === Signature line at the bottom of the page ===
        const sigY = 780;
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(10);
        doc.text('Signature: ___________________', 40,  sigY);
        doc.text('Name: ___________________',      230, sigY);
        doc.text('Date: ___________________',      420, sigY);

        // Return only the base64 body (strip the data-uri header)
        return doc.output('datauristring').split(',')[1];
    }

    // Helper: bold label + value side by side on one row
    labelValue(doc, label, value, x, y) {
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text(label, x, y);
        doc.setFont('helvetica', 'normal');
        doc.text(String(value), x + 70, y);
    }

    // Helper: underlined field row across the page
    fieldRow(doc, label, value, x, y) {
        doc.setFont('helvetica', 'bold');
        doc.text(label, x, y);
        doc.setFont('helvetica', 'normal');
        doc.text(String(value), x + 60, y);
        doc.line(x, y + 5, x + 515, y + 5);
    }

    // Helper: two label/value pairs sharing one underlined row
    twoFieldRow(doc, label1, value1, label2, value2, x, y) {
        doc.setFont('helvetica', 'bold');
        doc.text(label1, x, y);
        doc.setFont('helvetica', 'normal');
        doc.text(String(value1), x + 50, y);
        doc.setFont('helvetica', 'bold');
        doc.text(label2, x + 260, y);
        doc.setFont('helvetica', 'normal');
        doc.text(String(value2), x + 305, y);
        doc.line(x, y + 5, x + 515, y + 5);
    }

    // Helper: total row with bold label on the left and right-aligned dollar amount
    totalRow(doc, label, value, y) {
        doc.setFont('helvetica', 'bold');
        doc.text(label, 380, y);
        doc.setFont('helvetica', 'normal');
        doc.text('$' + Number(value || 0).toFixed(2), 555, y, { align: 'right' });
    }

    // Helper: ISO date to a friendlier display (kept simple)
    fmtDate(value) {
        if (!value) return '';
        return String(value).substring(0, 10);
    }

    // Helper: extract a meaningful message from any error shape
    extractError(e) {
        if (!e) return 'Unknown error';
        if (typeof e === 'string') return e;
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return JSON.stringify(e);
    }
}
