import { LightningElement, api } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationFormController.submitApplication';

const EMPTY_FORM = {
    companyName: '',
    federalTaxId: '',
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    annualRevenue: ''
};

export default class ApplicationForm extends LightningElement {
    @api cardTitle = 'Partner Application';

    formData = { ...EMPTY_FORM };

    isLoading = false;
    isSubmitted = false;
    submitError = '';
    resultRecordType = '';
    resultRecordId = '';

    handleChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
    }

    get isSubmitDisabled() {
        return this.isLoading;
    }

    get resultHeading() {
        return `Application submitted — ${this.resultRecordType} created`;
    }

    async handleSubmit(event) {
        event.preventDefault();
        this.submitError = '';

        if (!this.validateFields()) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await submitApplication({ input: this.buildInput() });
            if (result.success) {
                this.isSubmitted = true;
                this.resultRecordType = result.recordType;
                this.resultRecordId = result.recordId;
            } else {
                this.submitError = result.message || 'The application could not be processed.';
            }
        } catch (error) {
            this.submitError = this.extractErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.formData = { ...EMPTY_FORM };
        this.isSubmitted = false;
        this.submitError = '';
        this.resultRecordType = '';
        this.resultRecordId = '';
    }

    validateFields() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let allValid = true;
        inputs.forEach((input) => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });
        return allValid;
    }

    buildInput() {
        const revenue = this.formData.annualRevenue;
        return {
            companyName: this.formData.companyName,
            federalTaxId: this.formData.federalTaxId,
            firstName: this.formData.firstName,
            lastName: this.formData.lastName,
            email: this.formData.email,
            phone: this.formData.phone,
            annualRevenue: revenue === '' || revenue === null || revenue === undefined ? null : Number(revenue)
        };
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unexpected error occurred while submitting your application.';
    }
}
