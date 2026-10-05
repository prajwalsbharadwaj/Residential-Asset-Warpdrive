/**
 * WD Elite Residences — Channel Partner 360 App Logic
 */

document.addEventListener('DOMContentLoaded', async () => {
    const api = window.Broker360ApiClient;

    // DOM Elements
    const projectsGrid = document.getElementById('projects-grid');
    const cityFilterPills = document.querySelectorAll('.filter-pill');
    
    // Profile & KPI Elements
    const partnerNavName = document.getElementById('partner-nav-name');
    const profileName = document.getElementById('profile-name');
    const profileRera = document.getElementById('profile-rera');
    const profileSlab = document.getElementById('profile-slab');
    const profileTier = document.getElementById('profile-tier');

    const kpiInquiries = document.getElementById('kpi-inquiries');
    const kpiVisits = document.getElementById('kpi-visits');
    const kpiUnits = document.getElementById('kpi-units');
    const kpiCommission = document.getElementById('kpi-commission');
    const kpiPending = document.getElementById('kpi-pending');

    const inquiryCount = document.getElementById('inquiry-count');
    const bookingCount = document.getElementById('booking-count');

    // Tables
    const inquiriesTbody = document.getElementById('inquiries-tbody');
    const bookingsTbody = document.getElementById('bookings-tbody');
    const inquirySearch = document.getElementById('inquiry-search');

    // Tabs
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');

    // Modal
    const registerModal = document.getElementById('register-modal');
    const btnOpenModal = document.getElementById('btn-open-register-modal');
    const btnNavRegisterClient = document.getElementById('btn-nav-register-client');
    const btnQuickRegister = document.getElementById('btn-quick-register');
    const btnQuickRegisterTop = document.getElementById('btn-quick-register-top');
    const btnCloseModal = document.getElementById('btn-close-register-modal');
    const btnCancelModal = document.getElementById('btn-cancel-register');
    const registerForm = document.getElementById('register-client-form') || document.getElementById('register-buyer-form');

    // Chatbot Elements
    const chatLauncherBtn = document.getElementById('chat-launcher-btn');
    const chatDrawer = document.getElementById('chat-drawer');
    const chatCloseBtn = document.getElementById('chat-close-btn');
    const chatMessages = document.getElementById('chat-messages');
    const chatInput = document.getElementById('chat-input');
    const chatSendBtn = document.getElementById('chat-send-btn');
    const promptChips = document.querySelectorAll('.chip');
    const btnOpenConcierge = document.getElementById('btn-open-concierge');
    const navConciergeLink = document.getElementById('nav-concierge-link');

    let allProjects = [];
    let currentInquiries = [];

    // --- 1. INITIALIZE & FETCH DATA ---
    async function loadPortalData() {
        const data = await api.getBroker360Data();
        if (!data || !data.success) return;

        // Populate Profile
        if (data.profile) {
            partnerNavName.textContent = data.profile.name;
            profileName.textContent = data.profile.name;
            profileRera.textContent = data.profile.reraNumber;
            profileSlab.textContent = `${data.profile.brokeragePercentage}% on Agreement Value`;
            profileTier.textContent = data.profile.tier;
        }

        // Populate KPIs
        if (data.metrics) {
            kpiInquiries.textContent = data.metrics.totalInquiries;
            kpiVisits.textContent = data.metrics.verifiedSiteVisits;
            kpiUnits.textContent = data.metrics.unitsBooked;
            kpiCommission.textContent = `₹ ${data.metrics.totalCommissionEarned.toLocaleString('en-IN')}`;
            kpiPending.textContent = `₹ ${data.metrics.pendingDisbursement.toLocaleString('en-IN')} in disbursement`;
            inquiryCount.textContent = data.metrics.totalInquiries;
            bookingCount.textContent = data.metrics.unitsBooked;
        }

        // Store and Render Projects
        allProjects = data.projects || [];
        renderProjects(allProjects);

        // Store and Render Inquiries
        currentInquiries = data.inquiries || [];
        renderInquiries(currentInquiries);

        // Render Bookings
        renderBookings(data.bookings || []);
    }

    // --- 2. RENDER PROJECTS ---
    function renderProjects(projectsList) {
        if (!projectsGrid) return;
        projectsGrid.innerHTML = '';

        projectsList.forEach(p => {
            const card = document.createElement('div');
            card.className = 'project-card';
            card.innerHTML = `
                <div class="project-image-box">
                    <img src="${p.image || 'assets/luxury_facade.jpg'}" alt="${p.name}" class="project-img">
                    <span class="project-badge-tag">${p.tag || 'WD ELITE'}</span>
                </div>
                <div class="project-body">
                    <span class="project-city-tag">${p.city}</span>
                    <h3 class="project-name">${p.name}</h3>
                    <p style="font-size:0.8rem; color:var(--text-muted); margin-bottom:0.4rem;">${p.location || 'Prime Location'}</p>
                    <p style="font-size:0.75rem; color:var(--gold-light);">${p.typology || 'Luxury Residences'}</p>
                    
                    <div class="project-meta-strip">
                        <div>
                            <div style="font-size:0.65rem; color:var(--text-subtle); text-transform:uppercase;">Price</div>
                            <div class="project-price">${p.startingPrice}</div>
                        </div>
                        <div style="text-align:right;">
                            <div style="font-size:0.65rem; color:var(--text-subtle); text-transform:uppercase;">CP Brokerage</div>
                            <span class="project-cp-slab">${p.commissionSlab || '2.5% Slab'}</span>
                        </div>
                    </div>

                    <div class="project-actions">
                        <button class="btn-card-action" onclick="window.openClientModalForProject('${p.name}')">+ Tag Client</button>
                        <button class="btn-card-action" onclick="window.openProjectBrochure('${p.name}')">Brochure</button>
                    </div>
                </div>
            `;
            projectsGrid.appendChild(card);
        });
    }

    // City Filter handler
    cityFilterPills.forEach(pill => {
        pill.addEventListener('click', () => {
            cityFilterPills.forEach(p => p.classList.remove('active'));
            pill.classList.add('active');

            const selectedCity = pill.dataset.city;
            if (selectedCity === 'All') {
                renderProjects(allProjects);
            } else {
                const filtered = allProjects.filter(p => p.city === selectedCity);
                renderProjects(filtered);
            }
        });
    });

    // --- 3. RENDER INQUIRIES TABLE ---
    function renderInquiries(inquiriesList) {
        if (!inquiriesTbody) return;
        inquiriesTbody.innerHTML = '';

        if (inquiriesList.length === 0) {
            inquiriesTbody.innerHTML = `<tr><td colspan="9" style="text-align:center; padding:2rem; color:var(--text-muted);">No tagged client inquiries found matching your query.</td></tr>`;
            return;
        }

        inquiriesList.forEach(inq => {
            let stageBadge = 'badge-new';
            if (inq.stage.includes('Visit')) stageBadge = 'badge-visit';
            else if (inq.stage.includes('Negotiation') || inq.stage.includes('Cost Sheet')) stageBadge = 'badge-visit';
            else if (inq.stage.includes('Booking') || inq.stage.includes('Approved')) stageBadge = 'badge-booked';

            const unitHtml = inq.unitNumber
                ? `<span class="unit-link-badge" onclick="window.openUnitModal('${inq.unitNumber}', '${inq.projectName}')" title="Click to view Unit Specs &amp; Provisional Cost Sheet">
                    ${inq.unitNumber} ↗
                   </span>`
                : `<span class="badge-pending-alloc" title="Pre-sales allocation in progress">Pre-Sales Allocating</span>`;

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <a href="javascript:void(0)" class="table-link" onclick="window.openClientSummary('${inq.id}')">
                        <strong style="color:var(--text-white);">${inq.name}</strong>
                    </a>
                    <div style="font-size:0.7rem; color:var(--text-subtle);">Ref ID: ${inq.id}</div>
                </td>
                <td>
                    <div>${inq.phone}</div>
                    <div style="font-size:0.72rem; color:var(--text-muted);">${inq.email || ''}</div>
                </td>
                <td><strong style="color:var(--gold-light);">${inq.projectName}</strong></td>
                <td>${inq.configuration}</td>
                <td>${unitHtml}</td>
                <td style="font-family:var(--font-display); font-weight:600;">${inq.budget}</td>
                <td>
                    ${inq.hasSiteVisit 
                        ? `<span class="badge-status badge-verified">OTP Verified ✔</span>` 
                        : `<span class="badge-status badge-visit">Pending OTP</span>`}
                </td>
                <td><span class="badge-status ${stageBadge}">${inq.stage}</span></td>
                <td>
                    <button class="btn-summary-track" onclick="window.openClientSummary('${inq.id}')" title="View Client Journey &amp; Summary">
                        Client Details ↗
                    </button>
                </td>
            `;
            inquiriesTbody.appendChild(tr);
        });
    }

    // Search Inquiries Filter
    if (inquirySearch) {
        inquirySearch.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            const filtered = currentInquiries.filter(i => 
                i.name.toLowerCase().includes(query) || 
                i.phone.includes(query) || 
                i.projectName.toLowerCase().includes(query) ||
                (i.unitNumber && i.unitNumber.toLowerCase().includes(query))
            );
            renderInquiries(filtered);
        });
    }

    // --- 4. RENDER BOOKINGS TABLE (Tagged Units & Commission) ---
    function renderBookings(bookingsList) {
        if (!bookingsTbody) return;
        bookingsTbody.innerHTML = '';

        if (bookingsList.length === 0) {
            bookingsTbody.innerHTML = `<tr><td colspan="8" style="text-align:center; padding:2rem; color:var(--text-muted);">No bookings tagged to your Channel Partner account yet.</td></tr>`;
            return;
        }

        bookingsList.forEach(b => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <a href="javascript:void(0)" class="booking-link-badge" onclick="window.openClientSummary('${b.bookingNumber}')" title="Click to view complete client summary">
                        <strong style="color:var(--text-white); font-family:var(--font-mono);">${b.bookingNumber}</strong>
                        <span style="color:var(--gold); font-size:0.75rem;">↗</span>
                    </a>
                    <div style="font-size:0.7rem; color:var(--text-subtle); cursor:pointer;" onclick="window.openClientSummary('${b.bookingNumber}')">${b.clientName}</div>
                </td>
                <td><strong style="color:var(--gold-light);">${b.projectName}</strong></td>
                <td>
                    <span class="unit-link-badge" onclick="window.openUnitModal('${b.unitName}', '${b.projectName}')" title="Click to view Unit Specs &amp; Provisional Cost Sheet">
                        ${b.unitName} ↗
                    </span>
                </td>
                <td style="color:var(--text-muted);">${b.tower}</td>
                <td style="font-family:var(--font-display); font-weight:700;">₹ ${(b.agreementValue || 0).toLocaleString('en-IN')}</td>
                <td><span class="badge-slab">${b.commissionRate || 2.5}%</span></td>
                <td style="font-family:var(--font-display); font-weight:700; color:var(--gold);">₹ ${(b.brokerageValue || 0).toLocaleString('en-IN')}</td>
                <td>
                    <button class="btn-summary-track" onclick="window.openClientSummary('${b.bookingNumber}')" title="View Client Summary &amp; Milestone Ledger">
                        Client Details ↗
                    </button>
                </td>
            `;
            bookingsTbody.appendChild(tr);
        });
    }

    // --- 5. TABS CONTROLLER ---
    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            tabButtons.forEach(b => b.classList.remove('active'));
            tabPanes.forEach(p => p.classList.remove('active'));

            btn.classList.add('active');
            const targetPane = document.getElementById(btn.dataset.tab);
            if (targetPane) targetPane.classList.add('active');
        });
    });

    // --- 6. MODAL REGISTRATION CONTROLLER ---
    function openModal() {
        if (registerModal) registerModal.classList.add('open');
    }
    function closeModal() {
        if (registerModal) registerModal.classList.remove('open');
    }

    if (btnOpenModal) btnOpenModal.addEventListener('click', openModal);
    if (btnNavRegisterClient) btnNavRegisterClient.addEventListener('click', openModal);
    if (btnQuickRegister) btnQuickRegister.addEventListener('click', openModal);
    if (btnQuickRegisterTop) btnQuickRegisterTop.addEventListener('click', openModal);
    if (btnCloseModal) btnCloseModal.addEventListener('click', closeModal);
    if (btnCancelModal) btnCancelModal.addEventListener('click', closeModal);
    if (registerModal) {
        registerModal.addEventListener('click', (e) => {
            if (e.target === registerModal) closeModal();
        });
    }

    // Global helper for card button
    window.openClientModalForProject = function(projectName) {
        const selectProj = document.getElementById('select-project');
        if (selectProj) selectProj.value = projectName;
        openModal();
    };
    window.openBuyerModalForProject = window.openClientModalForProject;

    // Submit Client Registration
    if (registerForm) {
        registerForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const submitBtn = document.getElementById('btn-submit-register');
            submitBtn.textContent = 'Registering in SFDC...';
            submitBtn.disabled = true;

            const notesEl = document.getElementById('client-notes') || document.getElementById('buyer-notes');
            const payload = {
                brokerAccountId: api.mockData.profile.accountId,
                firstName: document.getElementById('first-name').value.trim(),
                lastName: document.getElementById('last-name').value.trim(),
                phone: document.getElementById('phone-number').value.trim(),
                email: document.getElementById('email-address').value.trim(),
                projectName: document.getElementById('select-project').value,
                configuration: document.getElementById('select-config').value,
                budget: '₹ 1.8 Cr+',
                notes: notesEl ? notesEl.value.trim() : ''
            };

            const result = await (api.registerClient ? api.registerClient(payload) : api.registerBuyer(payload));
            submitBtn.textContent = 'Onboard & Tag Client';
            submitBtn.disabled = false;

            if (result.success) {
                alert(`✔ Success!\n\n${result.message}`);
                registerForm.reset();
                closeModal();
                // Refresh views
                loadPortalData();
            } else {
                alert('Registration Error: ' + result.message);
            }
        });
    }

    // Optional Concierge Helper (Safe fallback)
    window.askConciergeAboutClient = function(clientName) {
        alert(`Status for client ${clientName}: Active in pipeline with mandatory site visit tracking.`);
    };

    // --- 8. BROKER OTP LOGIN MODAL CONTROLLER ---
    const otpModal = document.getElementById('otp-login-modal');
    const partnerPill = document.getElementById('partner-pill');
    const btnCloseOtp = document.getElementById('btn-close-otp-modal');
    const btnCancelOtp = document.getElementById('btn-cancel-otp');
    const btnRequestOtp = document.getElementById('btn-request-otp');
    const btnVerifyOtp = document.getElementById('btn-verify-otp');
    const otpEntryGroup = document.getElementById('otp-entry-group');
    const loginPhoneInput = document.getElementById('broker-login-phone');

    if (partnerPill) {
        partnerPill.addEventListener('click', () => {
            if (otpModal) otpModal.classList.add('open');
        });
    }

    function closeOtpModal() {
        if (otpModal) otpModal.classList.remove('open');
    }

    if (btnCloseOtp) btnCloseOtp.addEventListener('click', closeOtpModal);
    if (btnCancelOtp) btnCancelOtp.addEventListener('click', closeOtpModal);
    if (otpModal) {
        otpModal.addEventListener('click', (e) => {
            if (e.target === otpModal) closeOtpModal();
        });
    }

    if (btnRequestOtp) {
        btnRequestOtp.addEventListener('click', () => {
            const phone = loginPhoneInput.value.trim();
            if (!phone) {
                alert('Please enter a registered mobile number.');
                return;
            }
            btnRequestOtp.style.display = 'none';
            if (otpEntryGroup) otpEntryGroup.style.display = 'flex';
            if (btnVerifyOtp) btnVerifyOtp.style.display = 'inline-block';
            alert(`📲 SMS / WhatsApp Dispatched to ${phone}:\n\n"Your WD Elite Channel Partner verification code is 742891. Valid for 10 minutes. Do not share this OTP."`);
        });
    }

    if (btnVerifyOtp) {
        btnVerifyOtp.addEventListener('click', () => {
            const otp = document.getElementById('broker-login-otp').value.trim();
            if (otp !== '742891' && otp.length < 4) {
                alert('Invalid OTP code. Please enter 742891');
                return;
            }
            alert('✔ Authentication Successful!\n\nChannel Partner Account: Amit Raj (Apex Realty Partners)\nRERA Status: Active Verified\nZero Salesforce CRM user license required.');
            closeOtpModal();
            loadPortalData();
        });
    }

    // --- 9. B2B WHATSAPP PITCH GENERATOR ---
    window.shareWhatsAppPitch = function(projectName) {
        const pitchText = `*Exclusive Property Showcase — ${projectName}*\n\n` +
            `Hello! As an authorized RERA Channel Partner for WD Elite Residences, I am pleased to share priority allocation access for *${projectName}*.\n\n` +
            `• Configuration: Luxury 2, 3 & 4 BHK Residences\n` +
            `• Exclusive RERA Verified Pricing\n` +
            `• Private site visits with dedicated relationship manager\n\n` +
            `Let me know if you would like to review the layout plans or schedule an exclusive weekend site visit.`;

        if (navigator.clipboard) {
            navigator.clipboard.writeText(pitchText);
            alert(`✔ WhatsApp Pitch copied to clipboard for ${projectName}!\n\nYou can now paste it directly to prospective clients on WhatsApp:\n\n${pitchText}`);
        } else {
            alert(`WhatsApp Pitch for ${projectName}:\n\n${pitchText}`);
        }
    };

    // --- 10. TRANSACTION & CLIENT JOURNEY DOSSIER 360 CONTROLLER ---
    const dossierModal = document.getElementById('transaction-dossier-modal');
    const dossierTitle = document.getElementById('dossier-title');
    const dossierTag = document.getElementById('dossier-tag');
    const dossierInlineStats = document.getElementById('dossier-inline-stats');
    const dossierStepper = document.getElementById('dossier-stepper');
    const dossierContent = document.getElementById('dossier-content-area');
    const btnBackDossierTop = document.getElementById('btn-back-dossier-top');
    const btnCloseDossierModal = document.getElementById('btn-close-dossier-modal');
    const btnCloseDossierBottom = document.getElementById('btn-close-dossier-bottom');

    function closeDossier() {
        if (dossierModal) dossierModal.classList.remove('open');
    }

    if (btnBackDossierTop) btnBackDossierTop.addEventListener('click', closeDossier);
    if (btnCloseDossierModal) btnCloseDossierModal.addEventListener('click', closeDossier);
    if (btnCloseDossierBottom) btnCloseDossierBottom.addEventListener('click', closeDossier);

    if (dossierModal) {
        dossierModal.addEventListener('click', (e) => {
            if (e.target === dossierModal) closeDossier();
        });
    }

    // Global Escape Key Listener for all modals
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeDossier();
            closeUnitModal();
            closeBrochureModal();
            closeModal();
            closeOtpModal();
        }
    });

    // --- 10. CLIENT JOURNEY & SUMMARY CONTROLLER (FORMERLY DOSSIER 360) ---
    window.openClientSummary = window.openTransactionDossier = async function(identifier) {
        if (!api.getTransactionDossier) return;
        const d = await api.getTransactionDossier(identifier);
        if (!d) return;

        // 1. Header Identity & Badges
        const dossierRefBadge = document.getElementById('dossier-ref-badge');
        const dossierStatusBadge = document.getElementById('dossier-status-badge');
        const dossierInlineStats = document.getElementById('dossier-inline-stats');

        if (dossierTag) {
            dossierTag.textContent = d.type === 'BOOKING' ? 'BOOKING SUMMARY' : 'CLIENT JOURNEY & SUMMARY';
        }
        if (dossierRefBadge) {
            dossierRefBadge.textContent = `#${d.refNumber}`;
        }
        if (dossierStatusBadge) {
            dossierStatusBadge.textContent = d.status;
            dossierStatusBadge.className = 'badge-status ' + (d.status.toLowerCase().includes('book') || d.status.toLowerCase().includes('verified') ? 'badge-verified' : (d.status.toLowerCase().includes('nego') ? 'badge-booked' : 'badge-visit'));
        }
        if (dossierTitle) {
            dossierTitle.textContent = d.clientName || d.title.split('—')[0].trim();
        }

        // 2. Compact Inline Key Stats (Project, Unit, Agreement Value, CP Fee)
        if (dossierInlineStats) {
            const agrVal = d.agreementValue ? `₹ ${(d.agreementValue / 10000000).toFixed(2)} Cr` : '₹ 1.65 Cr';
            const commVal = d.brokerageValue ? `₹ ${(d.brokerageValue / 100000).toFixed(2)} L` : '₹ 4.12 L';
            const unitShort = (d.unitName || '').split('(')[0].trim();
            dossierInlineStats.innerHTML = `
                <span class="stat-chip-sub">• ${d.projectName} (${unitShort})</span>
                <span class="stat-chip-pill">Agr. Value: <strong>${agrVal}</strong></span>
                <span class="stat-chip-pill chip-emerald">CP Fee: <strong>${d.commissionRate}% (${commVal})</strong></span>
            `;
        }

        // 3. Ultra-Compact 1-Row Micro-Stepper Rail
        const steps = [
            { num: 1, name: 'Lead Tagged' },
            { num: 2, name: 'OTP Site Visit' },
            { num: 3, name: 'Negotiation' },
            { num: 4, name: 'Token & KYC' },
            { num: 5, name: 'Agreement' },
            { num: 6, name: 'Demands' },
            { num: 7, name: 'Handover' }
        ];

        if (dossierStepper) {
            dossierStepper.innerHTML = steps.map((s, idx) => {
                let stateClass = '';
                let icon = s.num;
                if (s.num < d.stageIndex) {
                    stateClass = 'done';
                    icon = '✔';
                } else if (s.num === d.stageIndex) {
                    stateClass = 'active';
                    icon = '●';
                }
                const isLast = idx === steps.length - 1;
                return `
                    <div class="stepper-node ${stateClass}">
                        <span class="stepper-icon">${icon}</span>
                        <span class="stepper-label">${s.name}</span>
                    </div>
                    ${!isLast ? '<span class="stepper-arrow">›</span>' : ''}
                `;
            }).join('');
        }

        // 4. Content Panels (The 6 modules requested by the client)
        if (dossierContent) {
            dossierContent.innerHTML = `
                <!-- PANEL 1: DISCUSSIONS MADE ON LEAD -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>📞 Lead Discussions &amp; Activity Log</span>
                        <span class="panel-title-badge">${d.discussions.length} Touchpoints Logged</span>
                    </div>
                    <div class="timeline-feed">
                        ${d.discussions.map(item => `
                            <div class="timeline-item">
                                <div class="timeline-meta">
                                    <span>${item.date}</span>
                                    <span class="timeline-channel">${item.channel}</span>
                                    <span style="color:var(--text-muted); font-weight:normal;">by ${item.author}</span>
                                </div>
                                <div class="timeline-notes">${item.notes}</div>
                            </div>
                        `).join('')}
                    </div>
                </div>

                <!-- PANEL 2: NEGOTIATION SUMMARY & CONCESSIONS -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>🤝 Negotiation Summary &amp; Approved Concessions</span>
                        <span class="panel-title-badge">Signed off by ${d.negotiation.approvedBy}</span>
                    </div>
                    <div class="negotiation-grid">
                        <div class="price-compare-card">
                            <div class="price-row">
                                <span style="color:var(--text-muted);">Standard Rack Price:</span>
                                <span style="text-decoration:line-through; color:var(--text-muted);">₹ ${(d.negotiation.basePrice).toLocaleString('en-IN')}</span>
                            </div>
                            <div class="price-row">
                                <span>Negotiated Agreement Value:</span>
                                <strong style="color:var(--emerald); font-size:1.05rem;">₹ ${(d.negotiation.finalPrice).toLocaleString('en-IN')}</strong>
                            </div>
                            <div class="price-row" style="border-top:1px dashed #D5CBBF; padding-top:0.4rem;">
                                <span>Total Client Benefit / Discount:</span>
                                <strong style="color:var(--gold);">₹ ${(d.negotiation.discountSavings).toLocaleString('en-IN')} (${d.negotiation.discountPercent})</strong>
                            </div>
                            <div style="font-size:0.75rem; color:var(--text-subtle); margin-top:0.3rem;">
                                Approval Token: <code style="font-family:var(--font-mono); font-weight:bold;">${d.negotiation.approvalRef}</code>
                            </div>
                        </div>

                        <div class="concessions-list">
                            <strong style="font-size:0.85rem; color:var(--text-white); margin-bottom:0.2rem;">Approved Concession Package:</strong>
                            ${d.negotiation.concessions.map(c => `
                                <div class="concession-item">
                                    <div>
                                        <strong style="color:var(--text-white);">${c.item}</strong>
                                        <div style="font-size:0.75rem; color:var(--text-muted);">${c.description}</div>
                                    </div>
                                    <span class="badge-status badge-verified">${c.value}</span>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                </div>

                <!-- PANEL 3: QUOTATION & COST SHEET BREAKDOWN -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>📋 Quotation &amp; Cost Sheet (RERA &amp; Statutory Taxes)</span>
                        <button class="btn-primary-sm" onclick="alert('Downloading Official Cost Sheet (${d.quotation.costSheetRef}) as PDF...')">
                            📥 Download Cost Sheet PDF
                        </button>
                    </div>
                    <table class="cost-table">
                        <tbody>
                            <tr>
                                <td>Unit Specification</td>
                                <td><strong>${d.unitName} (${d.quotation.carpetArea} Carpet | ${d.quotation.superBuiltUp} Super)</strong></td>
                            </tr>
                            <tr>
                                <td>Base Agreement Value</td>
                                <td><strong>₹ ${(d.quotation.baseAgreementValue).toLocaleString('en-IN')}</strong></td>
                            </tr>
                            <tr>
                                <td>RERA GST (5% Affordable Luxury Scheme)</td>
                                <td>+ ₹ ${(d.quotation.gstAmount).toLocaleString('en-IN')}</td>
                            </tr>
                            <tr>
                                <td>
                                    <div>Statutory Section 194-IA TDS (1% on Property &gt; ₹50 Lakhs)</div>
                                    <small style="color:var(--text-subtle);">Direct client remittance to Income Tax Department via Form 26QB</small>
                                </td>
                                <td style="color:var(--gold);">[Withheld: ₹ ${(d.quotation.statutoryTds194IA).toLocaleString('en-IN')}]</td>
                            </tr>
                            <tr>
                                <td>Stamp Duty &amp; Registration (5.6% State Surcharge)</td>
                                <td>+ ₹ ${(d.quotation.stampDuty).toLocaleString('en-IN')}</td>
                            </tr>
                            <tr class="total-row">
                                <td>Total All-Inclusive Investment Package</td>
                                <td style="color:var(--emerald);">₹ ${(d.quotation.allInclusiveTotal).toLocaleString('en-IN')}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <!-- PANEL 4: INSTALLMENTS PAID & MILESTONES CLEARED -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>💳 Installments &amp; Construction Milestones (Ledger)</span>
                        <span class="panel-title-badge">${d.installments.clearedMilestones} of ${d.installments.totalMilestones} Cleared</span>
                    </div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:1rem; font-size:0.85rem; padding:0.6rem 0.85rem; background:var(--bg-linen); border-radius:var(--radius-sm); border:1px solid var(--gold-border);">
                        <div>Total Collected: <strong style="color:var(--emerald);">₹ ${(d.installments.totalCollected).toLocaleString('en-IN')}</strong></div>
                        <div>Balance Remaining: <strong style="color:var(--rose);">₹ ${(d.installments.balanceRemaining).toLocaleString('en-IN')}</strong></div>
                    </div>
                    <div class="table-responsive">
                        <table class="milestones-table">
                            <thead>
                                <tr>
                                    <th>Milestone Name</th>
                                    <th>Demand Amount</th>
                                    <th>Cleared Date</th>
                                    <th>Bank / Escrow Ref</th>
                                    <th>Receipt #</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${d.installments.milestones.map(m => `
                                    <tr>
                                        <td><strong>${m.name}</strong></td>
                                        <td><strong>₹ ${(m.amount).toLocaleString('en-IN')}</strong></td>
                                        <td>${m.clearedDate}</td>
                                        <td style="font-family:var(--font-mono); font-size:0.75rem;">${m.bankRef}</td>
                                        <td style="font-family:var(--font-mono);">${m.receiptNo}</td>
                                        <td>
                                            <span class="badge-status ${m.status.includes('Paid') ? 'badge-verified' : (m.status.includes('Active') ? 'badge-visit' : 'badge-new')}">
                                                ${m.status}
                                            </span>
                                        </td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- PANEL 5: HANDOVER PROCEDURES & POSSESSION READINESS -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>🔑 Handover Procedures &amp; Possession Readiness</span>
                        <span class="panel-title-badge">Target: ${d.handover.targetPossession}</span>
                    </div>
                    <div class="handover-grid">
                        <div class="handover-tile">
                            <span class="handover-tile-label">RERA Construction</span>
                            <span class="handover-tile-value text-emerald">${d.handover.reraProgressPercent}% Complete</span>
                            <p class="handover-tile-desc">Structure cast; internal finishing, elevators, and MEP ongoing.</p>
                        </div>

                        <div class="handover-tile">
                            <span class="handover-tile-label">Occupancy Certificate (OC)</span>
                            <span class="handover-tile-value text-accent">In Verification</span>
                            <p class="handover-tile-desc">${d.handover.ocStatus}</p>
                        </div>

                        <div class="handover-tile">
                            <span class="handover-tile-label">Digital Snagging</span>
                            <span class="handover-tile-value">30-Day Window</span>
                            <p class="handover-tile-desc">${d.handover.snaggingProcedure}</p>
                        </div>

                        <div class="handover-tile">
                            <span class="handover-tile-label">Khata &amp; Registration</span>
                            <span class="handover-tile-value">Sub-Registrar Slot</span>
                            <p class="handover-tile-desc">${d.handover.khataRegistration}</p>
                        </div>
                    </div>
                </div>

                <!-- PANEL 6: CHANNEL PARTNER COMMISSION ATTRIBUTION -->
                <div class="dossier-card-panel">
                    <div class="dossier-panel-title">
                        <span>💰 Channel Partner Commission Attribution</span>
                        <span class="panel-title-badge">Slab: ${d.cpCommission.slabRate}</span>
                    </div>
                    <div class="cp-attribution-box">
                        <div class="cp-attr-row">
                            <span>Total Earned Brokerage:</span>
                            <strong style="color:var(--gold); font-size:1.15rem;">₹ ${(d.cpCommission.grossBrokerage).toLocaleString('en-IN')}</strong>
                        </div>
                        <div class="cp-attr-row">
                            <span>Statutory TDS Withholding (5% u/s 194H):</span>
                            <span style="color:var(--rose);">- ₹ ${(d.cpCommission.tdsWithheld).toLocaleString('en-IN')}</span>
                        </div>
                        <div class="cp-attr-row" style="border-top:1px dashed #D5CBBF; padding-top:0.4rem;">
                            <span>Net Commission Disbursed:</span>
                            <strong style="color:var(--emerald);">₹ ${(d.cpCommission.netDisbursed).toLocaleString('en-IN')}</strong>
                        </div>
                        <div class="cp-attr-row">
                            <span>Pending Milestone Release:</span>
                            <strong style="color:var(--amber);">₹ ${(d.cpCommission.pendingRelease).toLocaleString('en-IN')}</strong>
                        </div>
                    </div>

                    <div style="margin-top:1rem;">
                        <strong style="font-size:0.85rem; color:var(--text-white);">Commission Milestone Releases:</strong>
                        <div style="display:flex; flex-direction:column; gap:0.5rem; margin-top:0.5rem;">
                            ${d.cpCommission.releases.map(r => `
                                <div style="display:flex; justify-content:space-between; align-items:center; background:#FAF9F6; border:1px solid #ECE7DE; padding:0.5rem 0.85rem; border-radius:var(--radius-sm); font-size:0.8rem;">
                                    <div>
                                        <strong>${r.stage}</strong>
                                        <div style="font-size:0.72rem; color:var(--text-muted); font-family:var(--font-mono);">Ref: ${r.utr}</div>
                                    </div>
                                    <div style="text-align:right;">
                                        <strong>₹ ${(r.amount).toLocaleString('en-IN')}</strong>
                                        <div><span class="badge-status ${r.status.includes('Disbursed') ? 'badge-verified' : 'badge-visit'}">${r.status}</span></div>
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                </div>
            `;
        }

        // Open Modal
        dossierModal.classList.add('open');
    };

    // --- 11. UNIT DETAILS & PROVISIONAL COST SHEET CONTROLLER ---
    const unitModal = document.getElementById('unit-cost-modal');
    const btnCloseUnitModal = document.getElementById('btn-close-unit-modal');
    const btnCloseUnitBottom = document.getElementById('btn-close-unit-bottom');
    const btnImgInterior = document.getElementById('btn-img-interior');
    const btnImgFacade = document.getElementById('btn-img-facade');
    const btnImgPlan = document.getElementById('btn-img-plan');
    const unitPreviewImg = document.getElementById('unit-preview-img');

    function closeUnitModal() {
        if (unitModal) unitModal.classList.remove('open');
    }

    if (btnCloseUnitModal) btnCloseUnitModal.addEventListener('click', closeUnitModal);
    if (btnCloseUnitBottom) btnCloseUnitBottom.addEventListener('click', closeUnitModal);
    if (unitModal) {
        unitModal.addEventListener('click', (e) => {
            if (e.target === unitModal) closeUnitModal();
        });
    }

    window.openUnitModal = async function(unitCode, projectName) {
        if (!api.getUnitCostSheet) return;
        const u = await api.getUnitCostSheet(unitCode, projectName);
        if (!u) return;

        // Header info
        const unitModalCode = document.getElementById('unit-modal-code');
        const unitModalStatus = document.getElementById('unit-modal-status');
        const unitModalTitle = document.getElementById('unit-modal-title');
        const unitModalConfig = document.getElementById('unit-modal-config');
        const unitRateBadge = document.getElementById('unit-rate-badge');

        if (unitModalCode) unitModalCode.textContent = u.unitCode;
        if (unitModalStatus) {
            unitModalStatus.textContent = u.status;
            unitModalStatus.className = 'badge-status ' + (u.statusClass || 'badge-verified');
        }
        if (unitModalTitle) unitModalTitle.textContent = `${u.projectName} · ${u.tower} · Floor ${u.floor}`;
        if (unitModalConfig) unitModalConfig.textContent = `${u.configuration} · ${u.facing}`;
        if (unitRateBadge) unitRateBadge.textContent = `₹ ${u.baseRatePerSqFt.toLocaleString('en-IN')} / sq.ft`;

        // Architectural Specs
        const elCarpet = document.getElementById('unit-carpet-area');
        const elSbu = document.getElementById('unit-sbu-area');
        const elFacing = document.getElementById('unit-facing');
        const elParking = document.getElementById('unit-parking');
        const elPossession = document.getElementById('unit-possession');

        if (elCarpet) elCarpet.textContent = `${u.carpetAreaSqFt.toLocaleString('en-IN')} sq.ft`;
        if (elSbu) elSbu.textContent = `${u.superBuiltUpSqFt.toLocaleString('en-IN')} sq.ft`;
        if (elFacing) elFacing.textContent = u.facing;
        if (elParking) elParking.textContent = u.parkingSlots;
        if (elPossession) elPossession.textContent = u.possessionDate;

        // Itemized Cost Sheet
        const costBasic = document.getElementById('cost-basic');
        const costFloorDesc = document.getElementById('cost-floor-desc');
        const costFloorRise = document.getElementById('cost-floor-rise');
        const costPlc = document.getElementById('cost-plc');
        const costParking = document.getElementById('cost-parking');
        const costClubhouse = document.getElementById('cost-clubhouse');
        const costInfra = document.getElementById('cost-infra');
        const costAgr = document.getElementById('cost-agreement-val');
        const costGst = document.getElementById('cost-gst');
        const costStamp = document.getElementById('cost-stamp');
        const costTotal = document.getElementById('cost-total-outflow');
        const costToken = document.getElementById('cost-token');

        if (costBasic) costBasic.textContent = `₹ ${u.basicCost.toLocaleString('en-IN')}`;
        if (costFloorDesc) costFloorDesc.textContent = `Floor ${u.floor} × ₹ ${u.floorRiseRatePerSqFt}/sq.ft`;
        if (costFloorRise) costFloorRise.textContent = `₹ ${u.floorRise.toLocaleString('en-IN')}`;
        if (costPlc) costPlc.textContent = `₹ ${u.plc.toLocaleString('en-IN')}`;
        if (costParking) costParking.textContent = `₹ ${u.parkingCost.toLocaleString('en-IN')}`;
        if (costClubhouse) costClubhouse.textContent = `₹ ${u.clubhouseCost.toLocaleString('en-IN')}`;
        if (costInfra) costInfra.textContent = `₹ ${u.infraCost.toLocaleString('en-IN')}`;
        if (costAgr) costAgr.textContent = `₹ ${u.agreementValue.toLocaleString('en-IN')}`;
        if (costGst) costGst.textContent = `₹ ${u.gstAmount.toLocaleString('en-IN')}`;
        if (costStamp) costStamp.textContent = `₹ ${u.stampDuty.toLocaleString('en-IN')}`;
        if (costTotal) costTotal.textContent = `₹ ${u.totalProvisionalCost.toLocaleString('en-IN')}`;
        if (costToken) costToken.textContent = `₹ ${u.bookingToken.toLocaleString('en-IN')}`;

        // Photo Gallery Toggle
        if (unitPreviewImg) unitPreviewImg.src = u.images.interior;
        const pills = [btnImgInterior, btnImgFacade, btnImgPlan];
        pills.forEach(p => p && p.classList.remove('active'));
        if (btnImgInterior) btnImgInterior.classList.add('active');

        if (btnImgInterior) {
            btnImgInterior.onclick = () => {
                pills.forEach(p => p && p.classList.remove('active'));
                btnImgInterior.classList.add('active');
                if (unitPreviewImg) unitPreviewImg.src = u.images.interior;
            };
        }
        if (btnImgFacade) {
            btnImgFacade.onclick = () => {
                pills.forEach(p => p && p.classList.remove('active'));
                btnImgFacade.classList.add('active');
                if (unitPreviewImg) unitPreviewImg.src = u.images.facade;
            };
        }
        if (btnImgPlan) {
            btnImgPlan.onclick = () => {
                pills.forEach(p => p && p.classList.remove('active'));
                btnImgPlan.classList.add('active');
                if (unitPreviewImg) unitPreviewImg.src = u.images.interior;
            };
        }

        if (unitModal) unitModal.classList.add('open');
    };

    // --- 12. PROJECT SALES BROCHURE & UNIT CATALOG CONTROLLER ---
    const brochureModal = document.getElementById('brochure-modal');
    const btnCloseBrochureModal = document.getElementById('btn-close-brochure-modal');
    const btnCloseBrochureBottom = document.getElementById('btn-close-brochure-bottom');
    const btnBrochureWhatsApp = document.getElementById('btn-brochure-whatsapp');

    function closeBrochureModal() {
        if (brochureModal) brochureModal.classList.remove('open');
    }

    if (btnCloseBrochureModal) btnCloseBrochureModal.addEventListener('click', closeBrochureModal);
    if (btnCloseBrochureBottom) btnCloseBrochureBottom.addEventListener('click', closeBrochureModal);
    if (brochureModal) {
        brochureModal.addEventListener('click', (e) => {
            if (e.target === brochureModal) closeBrochureModal();
        });
    }

    window.printBrochure = function() {
        window.print();
    };

    window.openProjectBrochure = async function(projectName) {
        if (!api.getProjectBrochure) return;
        const b = await api.getProjectBrochure(projectName);
        if (!b) return;

        // Populate Header & Cover
        const tagEl = document.getElementById('brochure-modal-tag');
        const reraEl = document.getElementById('brochure-modal-rera');
        const coverRera = document.getElementById('brochure-cover-rera');
        const nameEl = document.getElementById('brochure-project-name');
        const locEl = document.getElementById('brochure-project-location');
        const heroImg = document.getElementById('brochure-hero-img');
        const captionEl = document.getElementById('brochure-caption');
        const descEl = document.getElementById('brochure-overview-desc');
        const escrowEl = document.getElementById('brochure-escrow-account');
        const dateEl = document.getElementById('brochure-footer-date');

        if (tagEl) tagEl.textContent = `${b.projectName} · Official Sales Collateral`;
        if (reraEl) reraEl.textContent = b.reraNumber;
        if (coverRera) coverRera.textContent = `RERA Reg: ${b.reraNumber}`;
        if (nameEl) nameEl.textContent = b.projectName;
        if (locEl) locEl.textContent = b.location;
        if (heroImg) heroImg.src = b.heroImage || 'assets/luxury_facade.jpg';
        if (captionEl) captionEl.textContent = b.caption || 'Architectural Elevation & Township Master Plan';
        if (descEl) descEl.textContent = b.overview;
        if (escrowEl) escrowEl.textContent = b.escrowAccount;
        if (dateEl) dateEl.textContent = `Issued ${new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' })} · Valid for authorized Channel Partner client circulation only`;

        // Amenities Grid
        const amenContainer = document.getElementById('brochure-amenities-container');
        if (amenContainer) {
            amenContainer.innerHTML = (b.amenities || []).map(a => `
                <div class="brochure-amenity-pill">
                    <span class="amenity-check">✓</span>
                    <span>${a}</span>
                </div>
            `).join('');
        }

        // Unit Configurations Table
        const unitsTbody = document.getElementById('brochure-units-tbody');
        if (unitsTbody) {
            unitsTbody.innerHTML = (b.units || []).map(u => `
                <tr>
                    <td><strong style="color:var(--text-white);">${u.config}</strong></td>
                    <td>${u.carpetArea}</td>
                    <td>${u.sbu}</td>
                    <td>${u.facing}</td>
                    <td style="font-family:var(--font-mono); font-weight:700; color:var(--gold);">${u.price}</td>
                    <td style="color:var(--text-muted); font-size:0.8rem;">${u.parking}</td>
                </tr>
            `).join('');
        }

        // Unit-Level USPs
        const uspContainer = document.getElementById('brochure-usp-container');
        if (uspContainer) {
            uspContainer.innerHTML = (b.usps || []).map(usp => `
                <div class="brochure-usp-card">
                    <div class="brochure-usp-card-title">${usp.title}</div>
                    <div class="brochure-usp-card-desc">${usp.desc}</div>
                </div>
            `).join('');
        }

        // WhatsApp Teaser Trigger
        if (btnBrochureWhatsApp) {
            btnBrochureWhatsApp.onclick = () => window.shareWhatsAppPitch(b.projectName);
        }

        if (brochureModal) brochureModal.classList.add('open');
    };

    // Run initial load
    loadPortalData();
});


