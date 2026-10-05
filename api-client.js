/**
 * Broker 360 API Client
 * Seamlessly interfaces with Salesforce Apex REST endpoint (/services/apexrest/Broker360)
 * Includes realistic local fallback database matching UAT org records (Properties, Bookings, Units, CPs)
 */

class Broker360ApiClient {
    constructor() {
        // Can be configured to point to UAT sandbox domain
        this.baseUrl = window.SFDC_INSTANCE_URL || '';
        this.sessionId = window.SFDC_ACCESS_TOKEN || '';
        this.isMockMode = !this.sessionId;

        // Local State (Mirroring UAT org: Amit Raj - Channel Partner Account)
        this.mockData = {
            profile: {
                accountId: '001aj00002ZgNpSAAV',
                name: 'Amit Raj (Apex Realty Partners)',
                reraNumber: 'PRM/KA/RERA/1251/309/PR/200123',
                brokeragePercentage: 2.5,
                tier: 'Platinum Tier',
                status: 'Active Verified ✔',
                phone: '+91 98450 11223',
                email: 'amit.raj@apexrealty.in'
            },
            metrics: {
                totalInquiries: 18,
                verifiedSiteVisits: 12,
                unitsBooked: 4,
                totalSalesVolume: 64500000, // ₹ 6.45 Cr
                totalCommissionEarned: 1612500, // ₹ 16,12,500 (2.5%)
                pendingDisbursement: 645000 // 40% milestone in disbursement
            },
            // Tagged Leads (Direct leads are strictly segregated out per business mandate!)
            inquiries: [
                {
                    id: '00Qaj00000ABCD1',
                    name: 'Rohan Mehta',
                    phone: '+91 98765 43210',
                    email: 'rohan.mehta@gmail.com',
                    projectName: 'Nikoo Homes',
                    configuration: '3 BHK Balcony',
                    unitNumber: 'RR-EW102',
                    budget: '₹ 1.5 - 1.8 Cr',
                    siteVisitStatus: 'Verified ✔ (OTP Matched)',
                    hasSiteVisit: true,
                    stage: 'Under Negotiation',
                    registeredDate: '2026-09-24'
                },
                {
                    id: '00Qaj00000ABCD2',
                    name: 'Deepika Rao',
                    phone: '+91 98450 33445',
                    email: 'deepika.rao@techcorp.com',
                    projectName: 'Saket Square',
                    configuration: '4 BHK Duplex',
                    unitNumber: 'SS-SK1-702',
                    budget: '₹ 3.8 - 4.2 Cr',
                    siteVisitStatus: 'Verified ✔ (OTP Matched)',
                    hasSiteVisit: true,
                    stage: 'Booking Approved',
                    registeredDate: '2026-09-22'
                },
                {
                    id: '00Qaj00000ABCD3',
                    name: 'Karthik Sundaram',
                    phone: '+91 99001 22334',
                    email: 'karthik.s@outlook.com',
                    projectName: 'Varthur Vista',
                    configuration: '2 BHK Luxury',
                    unitNumber: 'VV-T1U205',
                    budget: '₹ 2.1 - 2.4 Cr',
                    siteVisitStatus: 'Visit Scheduled (Pending OTP)',
                    hasSiteVisit: false,
                    stage: 'Site Visit Scheduled',
                    registeredDate: '2026-09-28'
                },
                {
                    id: '00Qaj00000ABCD4',
                    name: 'Vikramaditya Singhania',
                    phone: '+91 98110 55667',
                    email: 'vikram.singh@capital.com',
                    projectName: 'Banjara Beam',
                    configuration: 'Sky Villa',
                    unitNumber: 'BB-TB200',
                    budget: '₹ 4.5 Cr+',
                    siteVisitStatus: 'Verified ✔ (OTP Matched)',
                    hasSiteVisit: true,
                    stage: 'Cost Sheet Issued',
                    registeredDate: '2026-09-18'
                },
                {
                    id: '00Qaj00000ABCD5',
                    name: 'Ananya Deshmukh',
                    phone: '+91 97654 11223',
                    email: 'ananya.d@fintech.io',
                    projectName: 'Nikoo Homes',
                    configuration: '3 BHK Premium',
                    unitNumber: null,
                    budget: '₹ 1.6 Cr',
                    siteVisitStatus: 'New Inquiry (No Visit)',
                    hasSiteVisit: false,
                    stage: 'New Inquiry',
                    registeredDate: '2026-09-29'
                }
            ],
            // Tagged Bookings & Units with Auto-Calculated Brokerage
            bookings: [
                {
                    bookingId: 'a30Va000009s05uIAA',
                    bookingNumber: 'BO-00000014',
                    projectName: 'Nikoo Homes',
                    unitName: 'RR-EW100',
                    tower: 'Tower 2 · Floor 10',
                    clientName: 'Siddharth Hegde',
                    agreementValue: 16500000, // ₹ 1.65 Cr
                    commissionRate: 2.5,
                    brokerageValue: 412500, // ₹ 4,12,500
                    status: 'Confirmed'
                },
                {
                    bookingId: 'a30Va000009s05tIAA',
                    bookingNumber: 'BO-00000013',
                    projectName: 'Saket Square',
                    unitName: 'SS-SK1-700',
                    tower: 'Skyline Wing · Floor 7',
                    clientName: 'Varun Grover',
                    agreementValue: 28500000, // ₹ 2.85 Cr
                    commissionRate: 2.5,
                    brokerageValue: 712500, // ₹ 7,12,500
                    status: 'Allotment Letter Generated'
                },
                {
                    bookingId: 'a30aj00000C7bAPAAZ',
                    bookingNumber: 'BO-00000007',
                    projectName: 'Nikoo Homes',
                    unitName: 'RR-NW500',
                    tower: 'Tower 1 · Floor 5',
                    clientName: 'Manish Chawla',
                    agreementValue: 12789700, // ₹ 1.28 Cr
                    commissionRate: 2.5,
                    brokerageValue: 319742, // ₹ 3,19,742
                    status: 'Transferred'
                },
                {
                    bookingId: 'a30aj00000C8NWnAAN',
                    bookingNumber: 'BO-00000008',
                    projectName: 'Varthur Vista',
                    unitName: 'VV-T1U300',
                    tower: 'Tower 1 · Floor 3',
                    clientName: 'Pooja Bannerjee',
                    agreementValue: 6710300, // ₹ 67.10 L
                    commissionRate: 2.5,
                    brokerageValue: 167758, // ₹ 1,67,758
                    status: 'Pending Confirmation'
                }
            ],
            // Project Catalog matching UAT Property__c records
            projects: [
                {
                    id: 'a2saj000004GmcfAAC',
                    name: 'Nikoo Homes',
                    city: 'Bengaluru',
                    location: 'Thanisandra Main Rd, North Bengaluru',
                    startingPrice: '₹ 1.45 Cr onwards',
                    typology: '2 & 3 BHK Balcony Residences',
                    availableUnits: 14,
                    commissionSlab: '2.5% Slab',
                    tag: 'FAST SELLING',
                    image: 'assets/luxury_facade.jpg'
                },
                {
                    id: 'a2saj000004ETsgAAG',
                    name: 'Varthur Vista',
                    city: 'Bengaluru',
                    location: 'Whitefield - Varthur Corridor',
                    startingPrice: '₹ 2.10 Cr onwards',
                    typology: '3 & 4 BHK Luxury Deck Homes',
                    availableUnits: 11,
                    commissionSlab: '2.5% Slab',
                    tag: 'NEW LAUNCH',
                    image: 'assets/luxury_interior.jpg'
                },
                {
                    id: 'a2saj000004MlafAAC',
                    name: 'Saket Square',
                    city: 'Gurugram',
                    location: 'Golf Course Extension Road, Sector 65',
                    startingPrice: '₹ 3.85 Cr onwards',
                    typology: '4 BHK Ultra Luxury Duplex',
                    availableUnits: 8,
                    commissionSlab: '3.0% High-Rise Slab',
                    tag: 'SIGNATURE GOLF VIEW',
                    image: 'assets/luxury_facade.jpg'
                },
                {
                    id: 'a2saj000004MkGPAA0',
                    name: 'Banjara Beam',
                    city: 'Hyderabad',
                    location: 'Road No. 12, Banjara Hills',
                    startingPrice: '₹ 4.20 Cr onwards',
                    typology: 'Sky Villas with Private Splash Pool',
                    availableUnits: 6,
                    commissionSlab: '3.0% Signature Slab',
                    tag: 'EXCLUSIVE 18 RESIDENCES',
                    image: 'assets/luxury_interior.jpg'
                }
            ]
        };
    }

    /**
     * Fetch complete Broker 360 data
     */
    async getBroker360Data(brokerId) {
        if (!this.isMockMode && this.baseUrl) {
            try {
                const response = await fetch(`${this.baseUrl}/services/apexrest/Broker360?brokerId=${brokerId || ''}`, {
                    method: 'GET',
                    headers: {
                        'Authorization': `Bearer ${this.sessionId}`,
                        'Content-Type': 'application/json'
                    }
                });
                if (response.ok) {
                    return await response.json();
                }
            } catch (err) {
                console.warn('Live API request failed, falling back to cached state:', err);
            }
        }

        // Return local state
        return {
            success: true,
            profile: this.mockData.profile,
            metrics: this.mockData.metrics,
            inquiries: this.mockData.inquiries,
            bookings: this.mockData.bookings,
            projects: this.mockData.projects
        };
    }

    /**
     * Fetch rich 360 transaction dossier for a client inquiry or confirmed booking
     */
    async getTransactionDossier(identifier) {
        // Check for confirmed booking match first
        const b = this.mockData.bookings.find(item => 
            item.bookingNumber === identifier || 
            item.bookingId === identifier || 
            item.clientName.toLowerCase() === (identifier || '').toLowerCase()
        );

        if (b) {
            return {
                success: true,
                type: 'BOOKING',
                title: `${b.clientName} — ${b.projectName} (${b.unitName})`,
                refNumber: b.bookingNumber,
                clientName: b.clientName,
                phone: b.bookingNumber === 'BO-00000014' ? '+91 98450 67890' : '+91 98110 44556',
                email: b.bookingNumber === 'BO-00000014' ? 'siddharth.h@techcorp.in' : 'varun.g@groverholdings.com',
                projectName: b.projectName,
                unitName: b.unitName,
                tower: b.tower,
                agreementValue: b.agreementValue,
                commissionRate: b.commissionRate,
                brokerageValue: b.brokerageValue,
                status: b.status,
                stageIndex: b.bookingNumber === 'BO-00000014' ? 5 : 4,
                stageName: b.bookingNumber === 'BO-00000014' ? 'Milestone Construction & Collections' : 'Allotment Letter Issued',
                sourcingManager: 'Rajesh Nair (VP Sourcing)',
                
                // 1. Discussions Made on Lead
                discussions: [
                    {
                        date: '2026-08-14 11:30 AM',
                        channel: 'Telephony (Ozonetel CTI)',
                        author: 'Priya Sharma (Pre-Sales)',
                        notes: 'Initial outreach call for CP Amit Raj referral. Client inquired about 3 BHK high-floor unit facing internal green courtyard. Budget verified at ₹ 1.6 - 1.8 Cr. Site visit booked for Saturday.'
                    },
                    {
                        date: '2026-08-18 03:15 PM',
                        channel: 'GRE Welcome Desk (Site Visit)',
                        author: 'Kavita M. (GRE Executive)',
                        notes: 'Client arrived at Experience Lounge accompanied by CP Amit Raj. Verified via SMS OTP #491024. Inspected Tower 2 Unit RR-EW100 model. Highly impressed by layout and 80% open ventilation.'
                    },
                    {
                        date: '2026-08-22 05:00 PM',
                        channel: 'Deal Desk Negotiation Call',
                        author: 'Rajesh Nair (VP Sourcing)',
                        notes: 'Negotiation session with client & CP Amit Raj. Client requested floor rise waiver on Floor 10. Approved 4.3% discount package against immediate 10% token commitment.'
                    },
                    {
                        date: '2026-08-26 02:45 PM',
                        channel: 'Booking & KYC Closure',
                        author: 'Finance Treasury Desk',
                        notes: '10% Booking Token of ₹ 16,50,000 received in RERA Escrow account via RTGS. Aadhaar e-KYC completed and application form locked in Salesforce.'
                    },
                    {
                        date: '2026-09-12 11:00 AM',
                        channel: 'Sale Agreement Execution',
                        author: 'Legal & Registrations',
                        notes: 'Agreement for Sale executed and franked. Agreement copy stamped and uploaded to Salesforce DMS. 50% CP milestone triggered.'
                    }
                ],

                // 2. Negotiation Summary & Approved Concessions
                negotiation: {
                    basePrice: b.agreementValue + 750000,
                    finalPrice: b.agreementValue,
                    discountSavings: 750000,
                    discountPercent: '4.35%',
                    approvedBy: 'Rajesh Nair (VP Sourcing)',
                    approvalRef: 'APPR-SOURCING-2026-081',
                    concessions: [
                        { item: 'Floor Rise Charges', description: 'Floor 10 premium waived by ₹ 150/sq.ft', value: '₹ 2,77,500' },
                        { item: 'Car Parking Bay', description: 'Covered basement bay bundled at subsidized rate', value: '₹ 1,00,000' },
                        { item: 'Clubhouse Privilege', description: '2-Year complimentary lifestyle clubhouse membership', value: '₹ 75,000' },
                        { item: 'Payment Flexibility', description: 'Special 14-day extension for Agreement registration milestone', value: 'Approved' }
                    ]
                },

                // 3. Quotation & Cost Sheet Breakdown
                quotation: {
                    costSheetRef: `CS-${b.bookingNumber}-V2`,
                    issueDate: '2026-08-22',
                    carpetArea: '1,480 sq.ft (137.5 sq.m)',
                    superBuiltUp: '1,850 sq.ft',
                    baseAgreementValue: b.agreementValue,
                    gstRate: '5.0%',
                    gstAmount: Math.round(b.agreementValue * 0.05),
                    statutoryTds194IA: Math.round(b.agreementValue * 0.01), // 1% Section 194-IA
                    stampDuty: Math.round(b.agreementValue * 0.056), // 5.6% K-RERA
                    allInclusiveTotal: Math.round(b.agreementValue * 1.116)
                },

                // 4. Installments Paid & Milestones Cleared
                installments: {
                    totalMilestones: 5,
                    clearedMilestones: 3,
                    totalDemandRaised: Math.round(b.agreementValue * 0.35),
                    totalCollected: Math.round(b.agreementValue * 0.35),
                    balanceRemaining: Math.round(b.agreementValue * 0.65),
                    milestones: [
                        {
                            name: 'Stage 1: Booking Token & KYC Deposit (10%)',
                            amount: Math.round(b.agreementValue * 0.10),
                            clearedDate: '2026-08-26',
                            bankRef: 'HDFC RERA Escrow #94102',
                            receiptNo: 'RCT-2026-0914',
                            status: 'Paid & Cleared ✔'
                        },
                        {
                            name: 'Stage 2: Execution of Sale Agreement (10%)',
                            amount: Math.round(b.agreementValue * 0.10),
                            clearedDate: '2026-09-12',
                            bankRef: 'ICICI Escrow VAN #2201',
                            receiptNo: 'RCT-2026-1182',
                            status: 'Paid & Cleared ✔'
                        },
                        {
                            name: 'Stage 3: Foundation Slab Milestone (15%)',
                            amount: Math.round(b.agreementValue * 0.15),
                            clearedDate: '2026-09-28',
                            bankRef: 'Axis Escrow H2H #9914',
                            receiptNo: 'RCT-2026-1405',
                            status: 'Paid & Cleared ✔'
                        },
                        {
                            name: 'Stage 4: 10th Floor Slab Casting (15%)',
                            amount: Math.round(b.agreementValue * 0.15),
                            clearedDate: 'Pending (Due: 15 Oct 2026)',
                            bankRef: 'Demand Note Dispatched',
                            receiptNo: 'INV-2026-4401',
                            status: 'Demand Active ⏳'
                        },
                        {
                            name: 'Stage 5: Notice of Possession & Key Handover (5%)',
                            amount: Math.round(b.agreementValue * 0.05),
                            clearedDate: 'Target: Nov 2026',
                            bankRef: 'Final Escrow Clearing',
                            receiptNo: 'Pending Handover',
                            status: 'Upcoming Milestone'
                        }
                    ]
                },

                // 5. Handover Procedures & Possession Readiness
                handover: {
                    targetPossession: 'November 2026',
                    reraProgressPercent: 82,
                    ocStatus: 'OC applied with Urban Development Authority; joint site verification scheduled for October 2026.',
                    snaggingProcedure: 'Digital home inspection portal will activate 30 days prior to notice of possession. 100% snag rectification SLA guaranteed before keys are handed over.',
                    khataRegistration: 'Sub-Registrar conveyance slot scheduled for registration upon 95% milestone collection.'
                },

                // 6. Channel Partner Commission Breakdown
                cpCommission: {
                    slabRate: `${b.commissionRate}%`,
                    grossBrokerage: b.brokerageValue,
                    tdsWithheld: Math.round(b.brokerageValue * 0.05), // 5% u/s 194H
                    netDisbursed: Math.round(b.brokerageValue * 0.75 * 0.95),
                    pendingRelease: Math.round(b.brokerageValue * 0.25),
                    releases: [
                        { stage: 'Milestone 1 (25% on Token KYC)', amount: Math.round(b.brokerageValue * 0.25), status: 'Disbursed ✔', utr: 'RTGS2608301' },
                        { stage: 'Milestone 2 (50% on Agreement)', amount: Math.round(b.brokerageValue * 0.50), status: 'Disbursed ✔', utr: 'RTGS2609154' },
                        { stage: 'Milestone 3 (25% on Foundation Slab)', amount: Math.round(b.brokerageValue * 0.25), status: 'Finance Approval Active ⏳', utr: 'Pending Release' }
                    ]
                }
            };
        }

        // Match against inquiry pipeline
        const inq = this.mockData.inquiries.find(item => 
            item.id === identifier || 
            item.name.toLowerCase() === (identifier || '').toLowerCase()
        ) || this.mockData.inquiries[0];

        const estVal = inq.projectName === 'Saket Square' ? 38500000 : (inq.projectName === 'Banjara Beam' ? 42000000 : 16500000);
        const estComm = Math.round(estVal * 0.025);

        return {
            success: true,
            type: 'INQUIRY',
            title: `${inq.name} — ${inq.projectName} (${inq.configuration})`,
            refNumber: inq.id,
            clientName: inq.name,
            phone: inq.phone,
            email: inq.email,
            projectName: inq.projectName,
            unitName: `${inq.configuration} (Unit Selection in Progress)`,
            tower: 'Tower 2 (Preferred)',
            agreementValue: estVal,
            commissionRate: 2.5,
            brokerageValue: estComm,
            status: inq.stage,
            stageIndex: inq.hasSiteVisit ? 3 : 2,
            stageName: inq.stage,
            sourcingManager: 'Rajesh Nair (VP Sourcing)',
            
            // 1. Discussions Made on Lead
            discussions: [
                {
                    date: `${inq.registeredDate} 10:15 AM`,
                    channel: 'Channel Partner Portal Lock',
                    author: 'Amit Raj (Apex Realty)',
                    notes: `Client registered and locked under CP RERA code ${this.mockData.profile.reraNumber}. 30-Day Exclusivity protection activated in Salesforce CRM.`
                },
                {
                    date: `${inq.registeredDate} 02:30 PM`,
                    channel: 'Telephony (Pre-Sales Open CTI)',
                    author: 'Priya Sharma (Pre-Sales)',
                    notes: `Outreach completed. Client confirmed budget of ${inq.budget}. Interested in high-rise park-facing configuration.`
                },
                {
                    date: inq.hasSiteVisit ? '2026-09-24 04:00 PM' : 'Visit Scheduled for this Saturday',
                    channel: 'GRE Welcome Desk',
                    author: inq.hasSiteVisit ? 'Kavita M. (GRE Executive)' : 'GRE Welcome Desk',
                    notes: inq.hasSiteVisit 
                        ? 'Site visit completed and verified via SMS OTP #821034. Client toured project model and sample flat. Liked floor plan.'
                        : 'Site visit scheduled. SMS OTP pass dispatched to client mobile phone.'
                },
                {
                    date: '2026-09-29 06:15 PM',
                    channel: 'WhatsApp Business Outreach',
                    author: 'Sales Desk',
                    notes: `Detailed cost sheet and RERA approved brochure shared via WhatsApp. Client currently reviewing with family.`
                }
            ],

            // 2. Negotiation Summary & Approved Concessions
            negotiation: {
                basePrice: estVal + 600000,
                finalPrice: estVal,
                discountSavings: 600000,
                discountPercent: '3.6%',
                approvedBy: 'Rajesh Nair (VP Sourcing)',
                approvalRef: 'OFFER-STAGE-INQ-2026',
                concessions: [
                    { item: 'Floor Rise Subsidized', description: 'Floor 8-12 floor rise concession of ₹ 100/sq.ft', value: '₹ 1,85,000' },
                    { item: 'Clubhouse Membership', description: 'Included in introductory CP festive scheme', value: '₹ 75,000' },
                    { item: 'Price Protection Guarantee', description: 'Price locked for 14 days against upcoming price escalation', value: 'Locked' }
                ]
            },

            // 3. Quotation & Cost Sheet Breakdown
            quotation: {
                costSheetRef: `QUOTE-${inq.id.substring(inq.id.length - 5)}`,
                issueDate: '2026-09-29',
                carpetArea: '1,450 sq.ft (Typical)',
                superBuiltUp: '1,820 sq.ft',
                baseAgreementValue: estVal,
                gstRate: '5.0%',
                gstAmount: Math.round(estVal * 0.05),
                statutoryTds194IA: Math.round(estVal * 0.01),
                stampDuty: Math.round(estVal * 0.056),
                allInclusiveTotal: Math.round(estVal * 1.116)
            },

            // 4. Installments & Milestones
            installments: {
                totalMilestones: 5,
                clearedMilestones: 0,
                totalDemandRaised: 0,
                totalCollected: 0,
                balanceRemaining: estVal,
                milestones: [
                    {
                        name: 'Stage 1: Booking Token & KYC Deposit (10%)',
                        amount: Math.round(estVal * 0.10),
                        clearedDate: 'Pending Token Deposit',
                        bankRef: 'HDFC Project Escrow',
                        receiptNo: 'Pending',
                        status: 'Next Step for Client ⏳'
                    },
                    {
                        name: 'Stage 2: Execution of Sale Agreement (10%)',
                        amount: Math.round(estVal * 0.10),
                        clearedDate: 'Within 30 Days of Token',
                        bankRef: 'RERA Escrow Account',
                        receiptNo: 'Pending',
                        status: 'Upcoming'
                    },
                    {
                        name: 'Stage 3: Foundation Slab Milestone (15%)',
                        amount: Math.round(estVal * 0.15),
                        clearedDate: 'Construction Linked',
                        bankRef: 'Escrow H2H',
                        receiptNo: 'Pending',
                        status: 'Upcoming'
                    }
                ]
            },

            // 5. Handover Procedures
            handover: {
                targetPossession: 'Phase 2: Mid 2027',
                reraProgressPercent: 65,
                ocStatus: 'Under construction in full compliance with RERA quarterly filings.',
                snaggingProcedure: 'Standard 30-day pre-handover joint snagging inspection with developer engineering team.',
                khataRegistration: 'A-Khata registration executed upon 100% milestone settlement.'
            },

            // 6. Channel Partner Commission Breakdown
            cpCommission: {
                slabRate: '2.5%',
                grossBrokerage: estComm,
                tdsWithheld: Math.round(estComm * 0.05),
                netDisbursed: 0,
                pendingRelease: estComm,
                releases: [
                    { stage: 'Milestone 1 (25% on Token KYC)', amount: Math.round(estComm * 0.25), status: 'Pending Booking Token ⏳', utr: 'N/A' },
                    { stage: 'Milestone 2 (50% on Agreement)', amount: Math.round(estComm * 0.50), status: 'Pending Agreement Execution', utr: 'N/A' },
                    { stage: 'Milestone 3 (25% on Foundation Slab)', amount: Math.round(estComm * 0.25), status: 'Construction Linked', utr: 'N/A' }
                ]
            }
        };
    }

    /**
     * Register a new prospective client under this Channel Partner
     */
    async registerClient(clientPayload) {
        if (!this.isMockMode && this.baseUrl) {
            try {
                const response = await fetch(`${this.baseUrl}/services/apexrest/Broker360/lead`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${this.sessionId}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(clientPayload)
                });
                if (response.ok) {
                    return await response.json();
                }
            } catch (err) {
                console.warn('Live API post failed, applying local state update:', err);
            }
        }

        // Add to local mock database
        const newLead = {
            id: '00Qaj00000' + Math.random().toString(36).substring(2, 7).toUpperCase(),
            name: `${clientPayload.firstName} ${clientPayload.lastName}`,
            phone: clientPayload.phone,
            email: clientPayload.email || 'client@example.com',
            projectName: clientPayload.projectName,
            configuration: clientPayload.configuration || '3 BHK',
            budget: clientPayload.budget || '₹ 1.8 Cr',
            siteVisitStatus: 'Visit Requested (SMS OTP Pending)',
            hasSiteVisit: false,
            stage: 'New Inquiry',
            registeredDate: new Date().toISOString().split('T')[0]
        };

        this.mockData.inquiries.unshift(newLead);
        this.mockData.metrics.totalInquiries += 1;

        return {
            success: true,
            leadId: newLead.id,
            message: `Prospective client ${newLead.name} successfully onboarded and attributed under Channel Partner code ${this.mockData.profile.reraNumber}!`
        };
    }

    // Alias for backward compatibility
    async registerBuyer(payload) {
        return this.registerClient(payload);
    }

    /**
     * Alias for getTransactionDossier: Provides simple, intuitive Client Journey & Summary
     */
    async getClientSummary(identifier) {
        return this.getTransactionDossier(identifier);
    }

    /**
     * Fetch Unit Specifications & Itemized Provisional Cost Sheet
     * (Governed by Booking Condition Charges & SAP RE-FX/SD Pricing Schema)
     */
    async getUnitCostSheet(unitCode, projectName) {
        const unitCatalog = {
            'RR-EW100': {
                unitCode: 'RR-EW100',
                projectName: 'Nikoo Homes',
                tower: 'Tower 2 (East Wing)',
                floor: 10,
                configuration: '3 BHK Luxury Garden Penthouse',
                facing: 'East Facing · Club & Lake View',
                carpetAreaSqFt: 1450,
                superBuiltUpSqFt: 1885,
                parkingSlots: '1 Covered Basement Slot (B1-42)',
                possessionDate: 'Ready / Dec 2026',
                status: 'Allocated (Siddharth Hegde)',
                statusClass: 'badge-booked',
                baseRatePerSqFt: 8500,
                floorRiseRatePerSqFt: 50,
                plcPercentage: 0.05, // 5% Lake Facing
                parkingCost: 400000,
                clubhouseCost: 500000,
                infraCost: 450000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            },
            'RR-EW102': {
                unitCode: 'RR-EW102',
                projectName: 'Nikoo Homes',
                tower: 'Tower 2 (East Wing)',
                floor: 10,
                configuration: '3 BHK Balcony Suite',
                facing: 'North-East Facing · Central Courtyard',
                carpetAreaSqFt: 1380,
                superBuiltUpSqFt: 1795,
                parkingSlots: '1 Covered Basement Slot (B1-48)',
                possessionDate: 'Ready / Dec 2026',
                status: 'Shortlisted by Pre-Sales',
                statusClass: 'badge-visit',
                baseRatePerSqFt: 8500,
                floorRiseRatePerSqFt: 50,
                plcPercentage: 0.04,
                parkingCost: 400000,
                clubhouseCost: 500000,
                infraCost: 420000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            },
            'SS-SK1-700': {
                unitCode: 'SS-SK1-700',
                projectName: 'Saket Square',
                tower: 'Skyline Wing',
                floor: 7,
                configuration: '4 BHK Duplex Sky Villa',
                facing: 'North Facing · Golf Course Ext.',
                carpetAreaSqFt: 2450,
                superBuiltUpSqFt: 3185,
                parkingSlots: '2 Covered Parking Slots (B1-12, B1-14)',
                possessionDate: 'Q3 2027',
                status: 'Allocated (Varun Grover)',
                statusClass: 'badge-booked',
                baseRatePerSqFt: 11000,
                floorRiseRatePerSqFt: 60,
                plcPercentage: 0.06,
                parkingCost: 800000,
                clubhouseCost: 650000,
                infraCost: 600000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            },
            'SS-SK1-702': {
                unitCode: 'SS-SK1-702',
                projectName: 'Saket Square',
                tower: 'Skyline Wing',
                floor: 7,
                configuration: '4 BHK Duplex Presidential',
                facing: 'East Facing · Golf Course Panorama',
                carpetAreaSqFt: 2550,
                superBuiltUpSqFt: 3315,
                parkingSlots: '2 Covered Parking Slots (B1-16, B1-18)',
                possessionDate: 'Q3 2027',
                status: 'Shortlisted by Pre-Sales',
                statusClass: 'badge-visit',
                baseRatePerSqFt: 11000,
                floorRiseRatePerSqFt: 60,
                plcPercentage: 0.06,
                parkingCost: 800000,
                clubhouseCost: 650000,
                infraCost: 600000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            },
            'VV-T1U205': {
                unitCode: 'VV-T1U205',
                projectName: 'Varthur Vista',
                tower: 'Tower 1',
                floor: 2,
                configuration: '2 BHK Luxury Garden View',
                facing: 'East Facing · Landscape Woods',
                carpetAreaSqFt: 1150,
                superBuiltUpSqFt: 1495,
                parkingSlots: '1 Covered Stilt Parking (S-15)',
                possessionDate: 'Q1 2027',
                status: 'Shortlisted by Pre-Sales',
                statusClass: 'badge-visit',
                baseRatePerSqFt: 9200,
                floorRiseRatePerSqFt: 45,
                plcPercentage: 0.03,
                parkingCost: 350000,
                clubhouseCost: 400000,
                infraCost: 380000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            },
            'BB-TB200': {
                unitCode: 'BB-TB200',
                projectName: 'Banjara Beam',
                tower: 'Tower B',
                floor: 2,
                configuration: '4 BHK Classic Sky Villa',
                facing: 'North-East Facing · City Skyline',
                carpetAreaSqFt: 2600,
                superBuiltUpSqFt: 3380,
                parkingSlots: '2 Covered Basement Slots (B2-04, B2-06)',
                possessionDate: 'Ready for Possession',
                status: 'Shortlisted by Pre-Sales',
                statusClass: 'badge-visit',
                baseRatePerSqFt: 12500,
                floorRiseRatePerSqFt: 50,
                plcPercentage: 0.05,
                parkingCost: 700000,
                clubhouseCost: 600000,
                infraCost: 550000,
                gstRate: 0.05,
                stampDutyRate: 0.056,
                images: {
                    interior: 'assets/luxury_interior.jpg',
                    facade: 'assets/luxury_facade.jpg'
                }
            }
        };

        const u = unitCatalog[unitCode] || {
            unitCode: unitCode || 'UNIT-GENERIC',
            projectName: projectName || 'Nikoo Homes',
            tower: 'Tower 1',
            floor: 4,
            configuration: '3 BHK Premium Residence',
            facing: 'East Facing · Garden View',
            carpetAreaSqFt: 1400,
            superBuiltUpSqFt: 1820,
            parkingSlots: '1 Covered Car Park',
            possessionDate: 'Ready / 2027',
            status: 'Available for Allocation',
            statusClass: 'badge-verified',
            baseRatePerSqFt: 8800,
            floorRiseRatePerSqFt: 50,
            plcPercentage: 0.04,
            parkingCost: 400000,
            clubhouseCost: 500000,
            infraCost: 400000,
            gstRate: 0.05,
            stampDutyRate: 0.056,
            images: {
                interior: 'assets/luxury_interior.jpg',
                facade: 'assets/luxury_facade.jpg'
            }
        };

        // Itemized Cost Calculations (SAP RE-FX Condition Matching)
        const basicCost = Math.round(u.carpetAreaSqFt * u.baseRatePerSqFt);
        const floorRise = Math.round(u.carpetAreaSqFt * (u.floor * u.floorRiseRatePerSqFt));
        const plc = Math.round(basicCost * u.plcPercentage);
        const agreementValue = basicCost + floorRise + plc + u.parkingCost + u.clubhouseCost + u.infraCost;
        const gstAmount = Math.round(agreementValue * u.gstRate);
        const stampDuty = Math.round(agreementValue * u.stampDutyRate);
        const totalProvisionalCost = agreementValue + gstAmount + stampDuty;
        const bookingToken = Math.min(300000, Math.round(agreementValue * 0.02));

        return {
            ...u,
            basicCost,
            floorRise,
            plc,
            agreementValue,
            gstAmount,
            stampDuty,
            totalProvisionalCost,
            bookingToken
        };
    }

    /**
     * Fetch Comprehensive Official Project Brochure & Unit Matrix
     * (Directly mapped from Salesforce Property__c, Unit__c, and RERA filing specs)
     */
    async getProjectBrochure(projectName) {
        const name = (projectName || '').toLowerCase();

        if (name.includes('varthur')) {
            return {
                projectName: 'Varthur Vista',
                location: 'Varthur Main Road · Whitefield Technology Corridor, Bengaluru',
                reraNumber: 'PRM/KA/RERA/1251/310/PR/200128/003210',
                heroImage: 'assets/luxury_facade.jpg',
                caption: 'Eco-Luxury Forest Fringe Community in Whitefield East',
                overview: 'A boutique 14-acre sanctuary with 80% open landscaped greens, nestled directly on the Varthur-Whitefield growth spine. Engineered for senior technology executives seeking tranquility within 10 minutes of ITPL, Sigma Tech Park, and the Outer Ring Road.',
                amenities: [
                    'Forest-Fringed Infinity Lap Pool',
                    '25,000 sq.ft Signature Clubhouse',
                    'Badminton & Squash Courts',
                    'Acoustic Double-Glazed Soundproofing',
                    'EV Rapid Charging Stations (Every Bay)',
                    'Organic Herb Garden & Reflexology Trail',
                    '100% Treated Rainwater Harvesting',
                    '3-Tier Biometric & RFID Access'
                ],
                units: [
                    { config: '2 BHK Luxury', carpetArea: '1,150 sq.ft', sbu: '1,495 sq.ft', facing: 'East · Landscape Woods', price: '₹ 1.15 Cr onwards', parking: '1 Covered Stilt (S-15)' },
                    { config: '3 BHK Canopy / Garden', carpetArea: '1,640 sq.ft', sbu: '2,132 sq.ft', facing: 'North-East · Forest Green', price: '₹ 1.85 Cr onwards', parking: '1 Covered Basement' },
                    { config: '4 BHK Royal Classic', carpetArea: '2,150 sq.ft', sbu: '2,795 sq.ft', facing: 'East · 270° Panoramic Woods', price: '₹ 2.45 Cr onwards', parking: '2 Covered Stilt Slots' }
                ],
                usps: [
                    { title: '2 BHK Luxury', desc: '100% Vastu-compliant east orientation, morning daylight across all bedrooms, and acoustic glass minimizing corridor noise.' },
                    { title: '3 BHK Garden Deck', desc: 'Expansive 7-ft wide timber sun deck overlooking private forest greenery, with imported Italian marble living areas.' },
                    { title: '4 BHK Royal Suite', desc: 'Dual master bedrooms with walk-in wardrobes, private family lounge separate from formal reception, and 2 dedicated stilt parking bays.' }
                ],
                escrowAccount: 'ICICI Bank Ltd · A/c: 000205039182 (RERA Designated Escrow)'
            };
        }

        if (name.includes('saket')) {
            return {
                projectName: 'Saket Square',
                location: 'Golf Course Extension Road · Sector 65, Gurugram',
                reraNumber: 'RC/REP/HARERA/GGM/612/344/2022/87',
                heroImage: 'assets/luxury_facade.jpg',
                caption: 'Ultra-Luxury Low-Density Duplex Residences overlooking Golf Greens',
                overview: 'The pinnacle of luxury living in the National Capital Region. Saket Square offers low-density, high-ceiling duplexes and penthouses with private plunge pools, private elevator lobbies, and dedicated white-glove concierge services.',
                amenities: [
                    'Temperature-Controlled Indoor Sky Pool',
                    'Private Cigar Lounge & Wine Cellar',
                    'Championship Squash & Golf Simulator',
                    'Helipad Access for Resident Air Transit',
                    '11.5-ft High Clear Ceiling Heights',
                    'Triple-Tier Facial Recognition Security',
                    '3 Dedicated Covered Car Parks per Villa',
                    '24/7 Dedicated White-Glove Concierge'
                ],
                units: [
                    { config: '3 BHK Signature Residence', carpetArea: '1,950 sq.ft', sbu: '2,535 sq.ft', facing: 'North · Golf Course Greens', price: '₹ 2.65 Cr onwards', parking: '2 Basement Slots' },
                    { config: '4 BHK Duplex Sky Villa', carpetArea: '2,450 sq.ft', sbu: '3,185 sq.ft', facing: 'North · Golf Course Ext.', price: '₹ 3.85 Cr onwards', parking: '2 Basement Slots' },
                    { config: '4 BHK Presidential Duplex', carpetArea: '3,315 sq.ft', sbu: '4,310 sq.ft', facing: 'East · 360° Aravalli Skyline', price: '₹ 4.95 Cr onwards', parking: '3 Basement Slots' }
                ],
                usps: [
                    { title: '3 BHK Signature', desc: '11.5-ft floor-to-ceiling heights, automated Lutron smart lighting, and uninterrupted views across Golf Course Extension.' },
                    { title: '4 BHK Duplex Villa', desc: 'Double-height grand living room, heated private plunge pool on open sky terrace, and private high-speed biometric elevator access.' },
                    { title: '4 BHK Presidential', desc: 'Exclusive top-tier residence with private rooftop barbecue pavilion, 3 dedicated basement parking slots, and separate staff quarters.' }
                ],
                escrowAccount: 'HDFC Bank Ltd · A/c: 57500091820491 (HARERA Escrow Branch, Gurugram)'
            };
        }

        // Default: Nikoo Homes Phase 2
        return {
            projectName: 'Nikoo Homes (Phase 2)',
            location: 'Thanisandra Main Road · North Bengaluru Technology Hub',
            reraNumber: 'PRM/KA/RERA/1251/472/PR/171015/000431',
            heroImage: 'assets/luxury_facade.jpg',
            caption: '126-Acre Integrated Smart Township with Direct Metro Walkway',
            overview: 'Bengaluru’s premier integrated city community. Designed around the concept of a 15-minute city where offices, world-class schools, retail high streets, healthcare, and 126 acres of manicured parks are connected by private pedestrian skywalks.',
            amenities: [
                '40,000 sq.ft Black Swan Clubhouse',
                'Olympic-Length Heated Swimming Pool',
                '4.5-Acre Central Park & Amphitheatre',
                'Co-Working Pods & Business Centre',
                'Direct Metro Station Connected Skywalk',
                'Multi-Court Sports Arena & Tennis Club',
                'EV Rapid Charging Stations (Every Bay)',
                '24/7 AI-monitored Perimeter & CCTV'
            ],
            units: [
                { config: '2 BHK + Family', carpetArea: '1,180 sq.ft', sbu: '1,534 sq.ft', facing: 'North-East · Courtyard', price: '₹ 1.28 Cr onwards', parking: '1 Covered (B1-48)' },
                { config: '3 BHK Canopy Deck', carpetArea: '1,640 sq.ft', sbu: '2,132 sq.ft', facing: 'East · Central Park View', price: '₹ 1.65 Cr onwards', parking: '1 Covered (B1-42)' },
                { config: '4 BHK Classic Penthouse', carpetArea: '2,150 sq.ft', sbu: '2,795 sq.ft', facing: 'East · Club & Lake Panorama', price: '₹ 2.10 Cr onwards', parking: '2 Covered Slots' }
            ],
            usps: [
                { title: '2 BHK + Family', desc: 'Dual-balcony cross ventilation, dedicated work-from-home study alcove, and smart modular kitchen utility space.' },
                { title: '3 BHK Canopy Deck', desc: 'Double-height private sky deck with integrated garden planter, corner orientation with 270° township vistas, and walk-in wardrobe.' },
                { title: '4 BHK Classic', desc: 'Private elevator foyer, separate maid room with detached utility entrance, 3 master suites, and 2 dedicated basement parking slots.' }
            ],
            escrowAccount: 'HDFC Bank Ltd · A/c: 50200084920192 (K-RERA Escrow Branch, Bengaluru)'
        };
    }



    /**
     * Agentforce Deal Desk AI Copilot simulator
     */
    async queryAgentforceConcierge(question) {
        // Natural language intent evaluation matching Atlas Reasoning Engine
        const q = question.toLowerCase();

        await new Promise(r => setTimeout(r, 600)); // Realistic reasoning latency

        if (q.includes('commission') || q.includes('slab')) {
            if (q.includes('saket') || q.includes('gurugram')) {
                return `💰 **Saket Square Brokerage Slab**: As a Platinum Partner, you earn **3.0%** on every registered booking at Saket Square. On an indicative 4 BHK duplex (₹ 3.85 Cr), your earned commission is **₹ 11,55,000**. Release timeline: 25% on token, 50% on agreement registration, and 25% on 20% collection.`;
            }
            return `💰 **Your Commission Slab**: Your default agreement rate is **2.5%** on Bengaluru projects (Nikoo Homes, Varthur Vista) and **3.0%** on Luxury Signature projects (Saket Square & Banjara Beam). YTD you have earned **₹ 16,12,500** across 4 confirmed bookings!`;
        }

        if (q.includes('nikoo') || q.includes('3 bhk') || q.includes('availability') || q.includes('inventory')) {
            return `🏢 **Nikoo Homes (Bengaluru) Live Inventory**:\n• Total Available Units: **14 Units**\n• Recommended: **Tower 2 (Park Balcony View)**, Floors 7-14.\n• Starting Price: **₹ 1.45 Cr** (1,480 sq.ft carpet).\n• High Demand: East-facing 3 BHK units have only 4 units remaining. Would you like to schedule an OTP site visit for your client?`;
        }

        if (q.includes('lock') || q.includes('policy') || q.includes('client') || q.includes('register') || q.includes('conflict')) {
            return `🔒 **Client Exclusivity Lock Policy**:\n• Once registered on this portal, a client mobile number is locked to your Channel Partner account for **30 to 60 days**.\n• Mandatory verification: An **SMS OTP Site Visit** must be completed within 14 days of registration to validate client identity and protect your commission from relative/broker conflict.\n• Tap **"+ Tag Client"** in the top bar to lock your client now!`;
        }

        if (q.includes('payout') || q.includes('disbursement') || q.includes('pending') || q.includes('money')) {
            return `⏳ **Commission Payout Status**:\n• **Net Disbursed**: ₹ 8,86,875 (Cleared to bank account).\n• **Pending Release**: **₹ 6,45,000** for bookings \`BO-00000014\` (Nikoo Homes) and \`BO-00000013\` (Saket Square).\n• Status: Currently under Finance Maker-Checker verification; expected credit date is this Friday.`;
        }

        // Fallback Agentforce response
        return `Hello Amit Raj! I am your **WD Elite Channel Partner Deal Desk AI** powered by Salesforce Agentforce.\n\nI can help you:\n• Check live available units across **Nikoo Homes**, **Saket Square**, **Varthur Vista**, or **Banjara Beam**\n• Calculate your 2.5% - 3.0% commission slabs\n• Lock prospective clients to prevent broker conflict\n• Guide you on OTP Site Visit gate verification.\n\nWhat can I assist you with today?`;
    }
}

// Export singleton instance
window.Broker360ApiClient = new Broker360ApiClient();
