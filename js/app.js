(() => {
const { navGroups, opportunities, projects, customers, users, services } = window.AdminData;
const icon = window.icon;

const app = document.querySelector('#app');
const state = { route: location.hash.slice(1) || 'dashboard', menuOpen: false };

const badge = (text, type='') => `<span class="badge ${type}">${text}</span>`;
const tags = items => `<div class="tags">${items.map(x => `<span class="tag">${x}</span>`).join('')}</div>`;
const avatar = (letters, extra='') => `<span class="avatar ${extra}">${letters}</span>`;
const initials = name => name.split(' ').map(x => x[0]).slice(0,2).join('');

function sidebar(){
  return `<aside class="sidebar" id="main-navigation" aria-label="Main navigation">
    <div class="brand"><div class="brand-mark">${icon('shield',19)}</div><div><div class="brand-name">Disaster Logic</div><div class="brand-sub">Admin Console</div></div></div>
    <nav class="nav">${navGroups.map(group => `<div class="nav-label">${group.label}</div>${group.items.map(([id,ico,label,count]) => `<button class="nav-item ${routeActive(id)?'active':''}" data-route="${id}">${icon(ico)}<span>${label}</span>${count?`<span class="nav-badge">${count}</span>`:''}</button>`).join('')}`).join('')}</nav>
    <div class="sidebar-footer"><button type="button" class="side-action theme-toggle" data-action="theme" role="switch" aria-checked="${window.AdminTheme.current()==='dark'}">${icon('moon',14)} Dark Mode <span class="toggle" aria-hidden="true"></span></button><div class="side-action">${icon('bell',14)} Notifications <span class="notice-dot"></span></div><div class="side-action logout">${icon('logout',14)} Log Out</div></div>
  </aside>`;
}

function routeActive(id){
  if(state.route === 'opportunity-detail') return id === 'opportunities';
  if(state.route === 'user-detail') return id === 'user-management';
  return state.route === id;
}

function topbar(){
  return `<header class="topbar"><button class="mobile-menu" data-action="menu" aria-label="Open navigation" aria-controls="main-navigation" aria-expanded="${state.menuOpen}">${icon('menu',21)}</button><div class="global-search">${icon('search',14)}<input aria-label="Global search" placeholder="Search projects, customer names, or zip codes..."></div><div class="top-actions"><button class="primary" data-route="new-service" aria-label="New Service Request">${icon('plus',14)}<span>New Service Request</span></button>${icon('bell',17)}</div></header>`;
}

function layout(content){
  const booking = state.route === 'new-service';
  return `<div class="shell ${booking?'booking-layout':''} ${state.menuOpen?'menu-open':''}">${sidebar()}<button class="sidebar-overlay" aria-label="Close menu" data-action="menu" tabindex="-1"></button><main class="workspace">${booking?'':topbar()}<div class="content">${content}</div></main></div>`;
}

function pageHead(title, subtitle, actions='', eyebrow=''){
  return `<div class="page-head"><div>${eyebrow?`<div class="eyebrow">${eyebrow}</div>`:''}<h1 class="page-title">${title}</h1><p class="page-subtitle">${subtitle}</p></div>${actions?`<div class="head-actions">${actions}</div>`:''}</div>`;
}

function dashboard(){
  const jobs = [
    ['MS','Marcus Sterling','75001 (North Ridge)','Fire Damage Stabilization','Structural beam support & smoke clearance','Crew Alpha-3','Lead: J. Kowalski','In Progress','$14,200'],
    ['DC','David & Sarah Chen','75093 (Willow Creek)','Main Pipe Rupture Repair','Flood mitigation & drywall sanitation','Tech Squad 4','Lead: D. Miller','In Progress','$9,800'],
    ['TC','Trinity Community Ctr','75201 (Dallas Central)','Disaster Rebuild & Reinforcement','Structural framing phase & roof trussing','Apex Builders Team B','Lead: R. Ramirez','In Progress','$18,500'],
    ['BH','Blythe Harrison','75034 (Frisco South)','Electrical Hazard Isolation','Generator transfer switch installed & live tested','Certified Elec #2','Lead: M. Henderson','Completed','$6,450'],
    ['EW','Eleanor Wright','75024 (Plano East)','Emergency Roof Tarping','Heavy poly sheeting & barrier installation','Rapid Response 07','Lead: S. Vance','Completed','$8,200']
  ];
  return `<div class="stats">
    <div class="panel stat"><div class="stat-label">Pending</div><div class="stat-value">18 <span class="tiny">Queued Jobs</span></div><div class="stat-meta"><span>● &nbsp;Est. Pipeline Value</span><b style="color:#c85c00">$42,500</b></div><div class="stat-icon">${icon('briefcase',18)}</div></div>
    <div class="panel stat"><div class="stat-label">Paid</div><div class="stat-value green">$184,200</div><div class="stat-meta"><span style="color:#008b63">● Disbursed Settlement</span><b style="color:#007858">94 Jobs Done</b></div><div class="stat-icon">${icon('check',18)}</div></div>
    <div class="panel stat"><div class="stat-label">Total Estimate</div><div class="stat-value blue">$226,700</div><div class="stat-meta"><span style="color:#0759d3">● Total Active Portfolio</span><b style="color:#0759d3">112 Jobs</b></div><div class="stat-icon">${icon('briefcase',18)}</div></div>
  </div>
  <div class="panel referral-banner"><div class="round-icon">${icon('link',17)}</div><div class="referral-copy"><b>Referral Dispatch & Partner Network</b><div>Dispatch verified contractor partner assignments with instant priority intake routing.</div></div><div class="referral-code">∞ &nbsp; reliefsync.org/ref/TX-DISPATCH</div><button class="primary" data-route="quick-referral">${icon('plus',13)} Generate & Send Referral</button></div>
  <section class="panel"><div class="panel-titlebar"><div class="title-accent"></div><div><h2>Team Work Operations</h2><p>Active field dispatches and verified completed jobs</p></div><div class="panel-controls"><div class="select-like">All Work (In Progress & Completed)</div><button class="small-btn">${icon('download',12)} Export CSV</button></div></div><div class="table-scroll"><table class="data-table"><thead><tr><th>Client & Location</th><th>Scope of Work</th><th>Assigned Team / Crew</th><th>Status</th><th style="text-align:right">Amount / Estimate</th></tr></thead><tbody>${jobs.map(j=>`<tr><td><div class="person-cell">${avatar(j[0])}<div><div class="person-main">${j[1]}</div><div class="person-sub">${j[2]}</div></div></div></td><td><div class="job-main">${j[3]}</div><div class="person-sub">${j[4]}</div></td><td><div class="person-main">${j[5]}</div><div class="person-sub" style="color:#008463">${j[6]}</div></td><td><span class="status ${j[7]==='Completed'?'completed':''}">${j[7]}</span></td><td class="money">${j[8]}</td></tr>`).join('')}</tbody></table></div><div class="table-footer">Showing 5 of 112 total records<div class="pagination"><button class="page-num active">1</button><button class="page-num">2</button><button class="page-num">3</button><button class="page-num">›</button></div></div></section>`;
}

function opportunitiesView(){
  return `${pageHead('Opportunities','Review new jobs that match your coverage, service type, and availability.','','The Flood Team')}<div class="toolbar"><button class="chip">${icon('clock',12)} Emergency</button><button class="chip">${icon('calendar',12)} Today</button><button class="chip">${icon('calendar',12)} Scheduled</button><button class="chip">◉ Water</button><button class="chip">⌁ Plumbing</button></div><div class="panel search-strip">${icon('search',14)}<input placeholder="Search by customer name"><button class="strip-action">${icon('filter',12)} Filter</button></div><div class="opportunity-list">${opportunities.map(op => `<article class="panel op-card"><div class="op-photo" style="background-image:url('${op.image}')"><span class="photo-date">09/24/2026</span><div class="photo-meta"><span>LEAD<br><b>${op.lead}</b></span><span>${op.distance}</span></div></div><div class="op-body"><div class="op-kicker">Opportunity ${op.urgent?badge('Urgent','red'):''}</div><h2 class="op-name">${op.name}</h2><div class="address">${icon('pin',12)} ${op.address}</div><div class="op-info"><div class="info-box"><div class="info-label">Job Type</div><div class="info-value">${op.urgent?'🔴':'💧'} ${op.job}</div><div class="info-sub">Cause: ${op.cause}</div></div><div class="info-box"><div class="info-label">Schedule</div><div class="info-value">${icon('calendar',12)} ${op.date}</div><div class="info-sub">${op.time}</div></div></div><div class="op-footer">${tags(op.tags)}<div class="op-actions"><button class="small-btn" data-route="opportunity-detail">View</button><button class="small-btn blue" data-route="opportunity-detail">Accept</button></div></div></div></article>`).join('')}</div>`;
}

function projectsView(){
  const actions=`${badge('18 Active')} `;
  return `${pageHead(`Accepted Projects <span style="vertical-align:middle">${actions}</span>`,'Coordinate ongoing disaster restorations, track live fleet positioning, telemetry readings, and manage adjuster milestone sign-offs.')}<div class="panel search-strip">${icon('search',14)}<input placeholder="Search by customer name, address, or ID..."><div class="project-filters"><button class="small-btn blue">All &nbsp; 18</button><button class="small-btn">En Route</button><button class="small-btn">In Progress</button><button class="small-btn">Inspection</button></div></div>${projects.map(p=>`<article class="panel project-card"><div class="project-top"><div><div class="op-kicker">Accepted Project</div><h3>${p.name}</h3><div class="address">${icon('pin',11)} ${p.address}</div></div><div class="project-type">${p.type}<br><b>${p.value}</b></div></div><div class="project-grid"><div class="project-info"><div class="info-label">Job Type</div><div class="info-value">${p.job}</div><div class="person-sub">${p.cause}</div></div><div class="project-info"><div class="info-label">Schedule</div><div class="info-value">${p.schedule}</div><div class="person-sub">${p.note}</div></div><div class="project-action"><span class="tiny">View</span> <button class="small-btn blue">Open Project</button></div></div><div class="project-tags">${tags(p.tags)}</div></article>`).join('')}`;
}

function opportunityDetail(){
  return `${pageHead('Sarah Jenkins <span style="font-size:15px;font-weight:500">· Fire & Smoke Containment</span>','',`<button class="secondary" data-route="opportunities">${icon('arrow',13)} Back to<br>Opportunities</button><button class="primary">${icon('check',13)} Accept Opportunity</button>`,'Opportunities / Sarah Jenkins')}
  <div class="panel referral-banner"><div class="round-icon">${icon('briefcase',16)}</div><div class="referral-copy"><b>Standard Intake Pipeline Completed</b><div>Parsed strictly from customer submission. Review all 4 verified steps below before resource assignment.</div></div><button class="small-btn lightblue">☑ View Intake Form Capture</button></div>
  <div class="detail-layout"><div>
    <section class="panel step-card"><div class="step-head"><span class="step-number">1</span>Location & Coverage <span class="verified">Step 1 Verified</span></div><div class="step-body"><div class="coverage-grid"><div class="mini-box"><div class="mini-label">Postal Code / Area</div><div class="mini-value" style="font-size:23px;color:#1263d7">77002</div><div class="person-sub">Houston Metro District</div></div><div class="mini-box"><div class="mini-label">Coverage Status</div><div class="mini-value" style="color:#1263d7">◆ Downtown & Metro Area Triage Hub</div><div class="person-sub">Estimated arrival: 12–45 minutes</div></div></div><div class="map"><span class="map-controls">📍 77002 • Priority Dispatch Hub</span></div></div></section>
    <section class="panel step-card"><div class="step-head"><span class="step-number">3</span>Customer Details & Damage Scope <span class="verified">Step 3 Verified</span></div><div class="step-body"><div class="contact-grid"><div class="mini-box"><div class="mini-label">Full Name</div><div class="mini-value">Sarah Jenkins</div><div class="person-sub">Primary Homeowner</div></div><div class="mini-box"><div class="mini-label">Phone Number</div><div class="mini-value">+1 (555) 382-0014</div><div class="person-sub">SMS & Voice Enabled</div></div><div class="mini-box"><div class="mini-label">Email Address</div><div class="mini-value">s.jenkins@example.com</div><div class="person-sub">Sign Digital Email</div></div></div><div class="info-label" style="margin-top:12px">Urgent Damage Notes & Access Details</div><div class="note-box">“Fire damage localized around primary electrical cupboard and kitchen rafters. Smoke heavy on first floor. Gate code 84912.”</div><div class="info-label" style="margin-top:12px">Attached Damage Proof</div><div class="attachment"><img class="damage-photo" src="https://images.unsplash.com/photo-1523413363574-c30aa1c2a516?auto=format&fit=crop&w=300&q=80" alt="Fire damage"><div><b>damage_assessment_kitchen.jpg</b><div class="person-sub">2.4 MB • Uploaded via direct client mobile intake</div><div class="person-sub" style="color:#1761ce">↗ Full Resolution View &nbsp; △ Download</div></div>${badge('Verified')}</div></div></section>
  </div><div>
    <section class="panel step-card"><div class="step-head"><span class="step-number">2</span>Selected Service Type <span class="verified">Step 2 Verified</span></div><div class="step-body"><div class="service-choice"><div class="service-icon">🔥</div><div><b>Fire & Smoke Containment</b><div style="color:#e13c48;font-size:9px;margin-top:4px">Priority Triage · Immediate</div></div></div><p class="page-subtitle" style="line-height:1.55">Soot mitigation, structural rafter shoring, heavy air scrubbing & odor counteraction protocols to prevent secondary toxic fallout.</p>${tags(['HEPA Air Scrubbing','Rafter Shoring','Soot Wash'])}</div></section>
    <section class="panel step-card"><div class="step-head"><span class="step-number">4</span>Dispatch Priority & Availability <span class="verified">Step 4 Verified</span></div><div class="dispatch-card"><div class="info-box"><div class="info-label">Intake Selection</div><div class="info-value">🗓️ Scheduled Service Window ${badge('Confirmed')}</div></div><div class="dispatch-grid" style="margin-top:9px"><div class="mini-box"><div class="mini-label">Target Service Date</div><div class="mini-value">Tomorrow, Oct 24, 2025</div></div><div class="mini-box"><div class="mini-label">Requested Arrival Window</div><div class="mini-value">12 PM - 4 PM</div></div></div><div class="info-box" style="margin-top:9px"><div class="info-label">Guaranteed 2-Hour Arrival Notice</div><div class="person-sub">“Always Notify client 2 Hours beforehand.” Tech is automatically called dispatch prompt 60 minutes prior to physical entry.</div></div><button class="primary accept-wide">${icon('check',13)} Accept & Assign Field Unit</button><div class="audit">Lead ID: RS-77002-08823 &nbsp; • &nbsp; Recorded: 14 mins ago</div></div></section>
  </div></div>`;
}

function quickReferral(){
  return `${pageHead('Quick Referral','Assign a project to an external contractor or partner without creating an employee account. Generate a direct, secure referral link with tracking and payout permissions.',`${badge('ACTIVE FIELD LINKS')} <b>3 Live Encounters</b>`) }<div class="referral-grid"><section class="panel form-card"><div class="form-title">Create & Dispatch Referral</div><div class="form-step"><span class="step-number">1</span><b>Select Project to Refer</b></div><div class="field"><select><option>Sarah Jenkins — Fire & Smoke Containment (77002 Houston)</option></select></div><div class="estimate">Scope Estimate &nbsp; <b>$34,200.00 Total</b><br><span class="tiny">Window: Tomorrow 12:00 PM – 4:00 PM CST</span></div><div class="form-step"><span class="step-number">2</span><b>External Contractor Details</b></div><div class="tabs"><span class="tab active">Assign to Individual</span><span class="tab">Assign to Workspace</span><span class="tab">Show in Opportunities</span></div><div class="field"><label>Select Referral Contractor</label><select><option>Marcus Brody (Brody Emergency Restoration)</option></select></div><div class="split"><div class="field"><label>Contractor Full Name / Entity</label><input value="Marcus Brody (Brody Emergency)"></div><div class="field"><label>Direct Mobile (SMS Direct)</label><input value="+1 (555) 749-2041"></div></div><div class="split"><div class="field"><label>Primary Email Address</label><input value="mbrody@brodyrestoration.com"></div><div class="field"><label>Payout Upon Work Completion</label><input value="$ 3,200.00"></div></div><div class="field"><label>Special Instructions & Site Hazard Flags</label><textarea>Bring HEPA filtration and full containment equipment.</textarea></div></section><section class="panel link-card"><div class="form-title">Generated Link & Dispatch Panel</div><p class="page-subtitle">Contractor may review scope, accept live offer, upload damage photos, and initiate milestone release.</p><div class="field" style="margin-top:15px"><label>Secure Referral URL</label><div class="generated-link"><input value="reliefsync.app/referral/rfn-8842"><button class="small-btn">${icon('copy',12)} Copy</button></div></div><div class="send-buttons"><button class="small-btn">${icon('mail',12)} Send via SMS</button><button class="small-btn">${icon('mail',12)} Send via Email</button></div><div class="link-status">♢ Scope & Insurance Waiver Pre-Attached &nbsp; <b>Verified</b><br><br>◉ Direct Escrow Reserve Payout &nbsp; <b>$3,200.00 Held</b></div></section></div>${referralRecords()}`;
}

function referralRecords(){
  const rows=[['Jack Jenkins','Marcus Brody','Brody Emergency Restoration','$2,200.00','Draft/Not View','rn-8842-brody'],['Sarah Jenkins','Marcus Brody','Brody Emergency Restoration','$3,200.00','Link Sent Pending Arrival','rn-8842-brody'],['Abdullah Ramzan','Apex Drain & Septic','Trinity Vance Lead Tech(s)','$1,850.00','Started (In Progress)','rn-8849-apex'],['Elena Rostova','Gulf Coast Crane & Rigging','Dispatch Ops 04','$4,500.00','Finished (Payout Pending)','rn-8861-crane']];
  return `<section class="panel referral-table"><div class="table-scroll"><table class="data-table"><thead><tr><th>Project & Customer</th><th>External Contractor</th><th>Agreed Payout</th><th>Field Status</th><th>Referral Token</th><th>Actions</th></tr></thead><tbody>${rows.map(r=>`<tr><td><b>${r[0]}</b><div class="tiny">77002 Houston</div></td><td><b>${r[1]}</b><div class="tiny">${r[2]}</div></td><td><b>${r[3]}</b></td><td>${badge(r[4])}</td><td>${r[5]} &nbsp; ${icon('copy',10)}</td><td><button class="small-btn">View Portal</button></td></tr>`).join('')}</tbody></table></div><div class="table-footer">Showing 1–5 of 5 matches</div></section>`;
}

function customersView(){
  return `${pageHead('Customers','View and manage previous customers, their projects, and billing history.',`${badge('24 Previous Customers')} <button class="small-btn">${icon('download',12)} Export CSV</button>`)}<div class="panel search-strip">${icon('search',14)}<input placeholder="Search customer name, email, phone, or address..."><button class="small-btn">${icon('filter',11)} Filter</button><button class="small-btn">All Types</button><button class="small-btn">All Billing Status</button></div><section class="panel customer-table"><div class="table-scroll"><table class="data-table"><thead><tr><th>Customer</th><th>Type</th><th>Latest Project</th><th>Total Billed</th><th>Payment</th><th>Action</th></tr></thead><tbody>${customers.map(c=>`<tr><td><div class="person-cell">${avatar(c[0])}<div><div class="person-main">${c[1]}</div><div class="person-sub">${c[2]}</div></div></div></td><td>${badge(c[3])}</td><td><div class="job-main">${c[4]}</div><div class="person-sub">${c[5]}</div></td><td><b>${c[6]}</b></td><td>${badge('● '+c[7],c[7]==='Pending'?'red':'')}</td><td><span class="action-link">Details›</span></td></tr>`).join('')}</tbody></table></div><div class="table-footer">Showing 1 to 5 of 24 records<div class="pagination"><button class="page-num">‹</button><button class="page-num active">1</button><button class="page-num">›</button></div></div></section>`;
}

function userList(){
  return `${pageHead(`Users & Personnel <span style="vertical-align:middle">${badge('42 Total')}</span>`,'Manage workspace members, field technicians, partner contractors, and permission roles.',`<button class="small-btn">${icon('download',12)} Export CSV</button><button class="primary">${icon('plus',12)} Invite User</button>`)}<div class="panel search-strip">${icon('search',14)}<input placeholder="Search by name, role, email, or phone number..."><button class="small-btn">All Roles⌄</button><button class="small-btn">All Statuses⌄</button><button class="small-btn">◆ Workspace: The Flood Team</button></div><div class="users-list">${users.map(u=>`<article class="panel user-row">${avatar(u[0])}<span class="online-dot ${u[6]}"></span><div class="user-meta"><b>${u[1]}</b>${badge(u[2])}${u[3]?badge('♢ '+u[3]):''}</div><div class="user-contact"><span>${icon('mail',11)} ${u[4]}</span><span>${icon('phone',11)} ${u[5]}</span><span>♜ The Flood Team</span></div><button class="small-btn">Open Profile ${icon('chevron',10)}</button></article>`).join('')}</div><div class="table-footer">Showing 1 to 6 of 24 members<div class="pagination"><button class="page-num">‹ Previous</button><button class="page-num active">1</button><button class="page-num">2</button><button class="page-num">3</button><button class="page-num">4</button><button class="page-num">Next ›</button></div></div>`;
}

function userManagement(){
  const people=['Abdullah Ramzan','Andrea Agers','Andy Ayers','Dev Osborne','Willie Ford','David Shaw'];
  return `${pageHead('User Management','Manage user visibility, access to project types.',`<div class="segmented"><span class="active">Service Provider</span><span>Referral</span><span>Internal</span></div>`)}<div class="manage-list">${people.map((p,i)=>`<article class="panel manage-row"><div class="initial-box">${initials(p)}</div><div><b>${p}</b><div class="tiny">${p.toLowerCase().replace(' ','.')}@reliefsync.com</div></div>${badge(i%2?'All visibility':'Visibility')}<div class="manage-options">Open Profile ${icon('chevron',9)}</div><div class="manage-options">Available for matching ☐</div></article>`).join('')}</div>`;
}

function userDetail(){
  return `${pageHead('User Settings','Modify settings for this user and individual projects.',`<select class="select-like"><option>Field Contractor</option></select>`)}<section class="panel user-detail-head">${avatar('AR')}<div style="flex:1"><h2 style="margin:0 0 4px">Abdullah Ramzan</h2><div class="person-sub">abdullah.ramzan@floodguard.com</div><div style="margin-top:7px"><span class="verified-email">${icon('check',10)} Email verified</span> <span class="verified-email">${icon('phone',10)} MFA Enabled</span></div></div></section><div class="detail-sections"><section class="panel section-card"><div class="section-title">Basic Profile</div>${setting('user','Name & Credentials','Edit user profile and contact details','Active Admin')}${setting('mail','Service Area','Houston Metro / Downtown','Primary')}${setting('users','Availability','Select all service types and work status','Available')}</section><section class="panel section-card"><div class="section-title">Account</div>${setting('shield','General Information','Role, login and identity settings','Configured')}</section><section class="panel section-card"><div class="section-title">Settings</div>${setting('bell','Referrals','New referral alerts and routing','Active')}${setting('briefcase','Commission','Internal referral payout percentage','20%')}</section><section class="panel section-card"><div class="section-title">Financial Settings</div>${setting('briefcase','Payout details','Bank and tax payout information','Active')}</section></div>`;
}

function setting(ico,title,sub,value){return `<div class="setting-row"><span class="setting-icon">${icon(ico,14)}</span><div class="setting-copy"><b>${title}</b><div>${sub}</div></div>${badge(value)}${icon('chevron',11)}</div>`}

function coreServices(){
  return `${pageHead('Core Services','Determine which service types this workspace team can receive. The brand list is a source of the workspace account that is customer-definable.',`<button class="primary">${icon('plus',12)} New Core Service</button>`)}<section class="panel service-header-card"><div class="workspace-team"><span class="setting-icon">${icon('building',14)}</span><div><b>Workspace Team</b><div class="tiny">The Flood Team &nbsp; · &nbsp; Available &nbsp; · &nbsp; Saved</div></div></div></section><div class="service-grid">${services.map(s=>`<article class="panel service-card ${s[2]==='selected'?'selected':''}"><span class="service-check">${s[2]==='selected'?icon('check',11):''}</span><h3>${s[0]}</h3><p>${s[1]}</p>${s[2]==='warning'?'<span class="service-warning">Verification required</span>':''}</article>`).join('')}</div>`;
}

function emptyView(){
  const label=navGroups.flatMap(g=>g.items).find(x=>x[0]===state.route)?.[2] || 'Workspace';
  return `${pageHead(label,'')}<div class="panel empty-view">${label}</div>`;
}

function render(){
  window.BookingView.unmount();
  const views={dashboard,opportunities:opportunitiesView,'opportunity-detail':opportunityDetail,projects:projectsView,'quick-referral':quickReferral,customers:customersView,'user-list':userList,'user-management':userManagement,'user-detail':userDetail,'core-services':coreServices,'new-service':window.BookingView.render};
  app.innerHTML=layout((views[state.route]||emptyView)());
  syncMenu();
  if(state.route==='new-service') window.BookingView.mount(app.querySelector('#booking-form'));
  window.scrollTo(0,0);
}

const mobileLayout = window.matchMedia('(max-width: 900px)');

function syncMenu(){
  const open = mobileLayout.matches && state.menuOpen;
  document.body.classList.toggle('menu-open', open);
  app.querySelector('.shell').classList.toggle('menu-open', open);
  app.querySelector('.sidebar').inert = mobileLayout.matches && !open;
  app.querySelector('.workspace').inert = open;
  const toggle = app.querySelector('.mobile-menu');
  toggle.setAttribute('aria-expanded', String(open));
  toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
}

function setMenu(open){
  state.menuOpen = open;
  syncMenu();
  const focusTarget = open
    ? app.querySelector('.nav-item.active') || app.querySelector('.nav-item')
    : app.querySelector('.mobile-menu');
  focusTarget?.focus({ preventScroll: true });
}

app.addEventListener('click', e=>{
  const route=e.target.closest('[data-route]')?.dataset.route;
  const action=e.target.closest('[data-action]')?.dataset.action;
  if(route){
    state.route=route;
    state.menuOpen=false;
    if(location.hash !== `#${route}`) location.hash=route;
    else render();
  }
  if(action==='menu') setMenu(!state.menuOpen);
  if(action==='theme') window.AdminTheme.toggle();
});
document.addEventListener('keydown', e=>{
  if(!state.menuOpen || !mobileLayout.matches) return;
  if(e.key==='Escape'){ e.preventDefault(); setMenu(false); }
  if(e.key==='Tab'){
    const items = app.querySelectorAll('.sidebar button');
    const first = items[0];
    const last = items[items.length - 1];
    if(e.shiftKey && document.activeElement===first){ e.preventDefault(); last.focus(); }
    else if(!e.shiftKey && document.activeElement===last){ e.preventDefault(); first.focus(); }
  }
});
mobileLayout.addEventListener('change',()=>{state.menuOpen=false;syncMenu()});
window.addEventListener('hashchange',()=>{state.route=location.hash.slice(1)||'dashboard';state.menuOpen=false;render()});
render();
})();
