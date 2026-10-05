import { LightningElement, track, wire } from 'lwc';
import getProperties from '@salesforce/apex/SiteVisitController.getProperties';
import getTowers from '@salesforce/apex/SiteVisitController.getTowers';
import getUnits from '@salesforce/apex/SiteVisitController.getUnits';
import findExistingLead from '@salesforce/apex/SiteVisitController.findExistingLead';
import submitData from '@salesforce/apex/SiteVisitController.submitData';

export default class SiteVisitFeedback extends LightningElement {
    // Tracking form data
    @track firstName = '';
    @track lastName = '';
    @track mobile = '';
    @track email = '';
    @track leadId = null;

    @track propertyOptions = [];
    @track towerOptions = [];
    @track unitOptions = [];
    
    // UI State
    isTowerDisabled = true;
    isUnitDisabled = true;
    showAgentSig = false;

    // Hardcoded options
    sourceOptions = [
        { label: 'Digital/Web', value: 'Digital' },
        { label: 'Agent', value: 'Agent' }
    ];
    ratingOptions = [
        { label: 'Excellent', value: 'Excellent' },
        { label: 'Good', value: 'Good' }, 
        { label: 'Average', value: 'Average' }, 
        { label: 'Poor', value: 'Poor' }
    ];

    // Fetch Properties on Load
    @wire(getProperties)
    wiredProps({ data, error }) {
        if (data) {
            this.propertyOptions = data.map(p => ({ label: p.Name, value: p.Id }));
        } else if (error) {
            console.error('Error fetching properties', error);
        }
    }

    // Combined Identity Handler (fixes the Cactus error)
    handleIdentityInput(e) {
        const field = e.target.name;
        this[field] = e.target.value;

        // Only search if input is meaningful
        if (this.mobile?.length >= 10 || (this.email?.includes('@') && this.email?.includes('.'))) {
            findExistingLead({ phone: this.mobile, email: this.email })
                .then(res => {
                    // BEST PRACTICE: Null check prevents component crash
                    if (res) {
                        this.firstName = res.FirstName;
                        this.lastName = res.LastName;
                        this.leadId = res.Id;
                    } else {
                        // Keep current inputs if no lead is found
                        this.leadId = null;
                    }
                })
                .catch(err => console.error('Lead lookup failed', err));
        }
    }

    // Cascading Dropdowns
    handlePropertyChange(e) {
        this.selectedProp = e.detail.value;
        getTowers({ propertyId: this.selectedProp }).then(res => {
            this.towerOptions = res.map(t => ({ label: t.Name, value: t.Id }));
            this.isTowerDisabled = false;
            this.isUnitDisabled = true; // Reset unit if property changes
        });
    }

    handleTowerChange(e) {
        this.selectedTower = e.detail.value;
        getUnits({ towerId: this.selectedTower }).then(res => {
            this.unitOptions = res.map(u => ({ label: u.Name, value: u.Id }));
            this.isUnitDisabled = false;
        });
    }

    handleSourceChange(e) {
        this.showAgentSig = (e.detail.value === 'Agent');
        if (this.showAgentSig) {
            // Wait for re-render to find the new canvas
            setTimeout(() => this.initCanvas('.agent-pad'), 100);
        }
    }

    // Canvas Logic
    renderedCallback() {
        this.initCanvas('.customer-pad');
    }

    initCanvas(selector) {
        const canvas = this.template.querySelector(selector);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        canvas.width = canvas.offsetWidth;
        canvas.height = 150;
        let drawing = false;

        const getPos = (e) => {
            const rect = canvas.getBoundingClientRect();
            return {
                x: (e.clientX || e.touches[0].clientX) - rect.left,
                y: (e.clientY || e.touches[0].clientY) - rect.top
            };
        };

        const draw = (e) => {
            if (!drawing) return;
            const pos = getPos(e);
            ctx.lineWidth = 2;
            ctx.lineCap = 'round';
            ctx.lineTo(pos.x, pos.y);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(pos.x, pos.y);
        };

        canvas.addEventListener('mousedown', () => drawing = true);
        canvas.addEventListener('mousemove', draw);
        canvas.addEventListener('mouseup', () => { drawing = false; ctx.beginPath(); });
        canvas.addEventListener('touchstart', (e) => { drawing = true; draw(e); e.preventDefault(); }, {passive: false});
        canvas.addEventListener('touchmove', (e) => { draw(e); e.preventDefault(); }, {passive: false});
        canvas.addEventListener('touchend', () => { drawing = false; ctx.beginPath(); });
    }

    // Final Submission
    handleSubmit() {
        // Collect data into the Wrapper structure
        const info = {
            leadId: this.leadId,
            firstName: this.template.querySelector('[name="firstName"]').value,
            lastName: this.template.querySelector('[name="lastName"]').value,
            mobile: this.mobile,
            email: this.email,
            propertyId: this.selectedProp,
            towerId: this.selectedTower,
            unitId: this.template.querySelector('[name="unitId"]').value,
            interactionRating: this.template.querySelector('[name="rating"]').value,
            overallExperience: this.template.querySelector('[name="overall"]').value
        };

        const custSig = this.template.querySelector('.customer-pad').toDataURL();
        const agSig = this.showAgentSig ? this.template.querySelector('.agent-pad').toDataURL() : null;

        // Basic Validation
        if(!info.lastName || !info.mobile || !info.propertyId) {
            alert('Please fill in all required fields.');
            return;
        }

        submitData({ data: info, customerSig: custSig, agentSig: agSig })
            .then(() => {
                alert('Success! Site Visit recorded.');
                location.reload();
            })
            .catch(error => {
                alert('Submission Error: ' + (error.body ? error.body.message : error.message));
            });
    }

    clearCustomerPad() { this.clearCanvas('.customer-pad'); }
    clearAgentPad() { this.clearCanvas('.agent-pad'); }
    
    clearCanvas(sel) {
        const c = this.template.querySelector(sel);
        if(c) c.getContext('2d').clearRect(0, 0, c.width, c.height);
    }
}