import { LightningElement, api } from 'lwc';

export default class ThemedMessageBox extends LightningElement {
    @api messageText = 'Default Text';
    @api theme = 'Default';
    @api texture = 'None';

    themeMap = {
        'Default': 'slds-theme_default',
        'Shade': 'slds-theme_shade',
        'Inverse': 'slds-theme_inverse',
        'Alternate Inverse': 'slds-theme_alt-inverse',
        'Success': 'slds-theme_success',
        'Info': 'slds-theme_info',
        'Warning': 'slds-theme_warning',
        'Error': 'slds-theme_error',
        'Offline': 'slds-theme_offline'
    };

    textureMap = {
        'None': 'none',
        'Alert': 'alert'
    };

    get boxClass() {
        let classes = '';

        const themeClass = this.themeMap[this.theme];
        if (themeClass) {
            classes += `${themeClass} `;
        } else {
            classes += 'slds-theme_default ';
        }

        const textureValue = this.textureMap[this.texture];
        if (textureValue === 'alert') {
            classes += 'slds-theme_alert-texture';
        }

        return classes.trim();
    }
}