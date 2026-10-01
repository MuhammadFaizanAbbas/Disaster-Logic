(() => {
const navGroups = [
  {
    label: 'Operational Core',
    items: [
      ['dashboard', 'grid', 'Dashboard'],
      ['opportunities', 'briefcase', 'Opportunities', '128'],
      ['projects', 'check-square', 'My Projects', '18'],
      ['quick-referral', 'link', 'Quick Referral'],
      ['customers', 'users', 'Customers'],
      ['profile', 'user', 'Profile']
    ]
  },
  {
    label: 'Workspace Admin',
    items: [
      ['user-list', 'users', 'User List'],
      ['user-management', 'shield', 'User Management'],
      ['user-tiers', 'id-card', 'User Tiers'],
      ['core-services', 'network', 'Core Services'],
      ['location', 'pin', 'Location'],
      ['workspace', 'building', 'Workspace']
    ]
  }
];

const opportunities = [
  {
    name: 'Abdullah Ramzan', address: '4020 Mitchford Dr, St. Louis, MO 63125, USA',
    job: 'Drain Cleaning + Sewage Clean-up', cause: 'Drain or Sewer Backup', date: 'September 24, 2026',
    time: '1:00 PM - 2:00 PM Central Time', tags: ['Drain Cleaning', 'Sewage Clean-up'], lead: '17', distance: '6.8 mi away',
    image: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=720&q=85'
  },
  {
    name: 'Marcus Sterling', address: '7812 Oakridge Pkwy, St. Louis, MO 63119, USA',
    job: 'Fire & Smoke Containment + Board-up', cause: 'Kitchen Fire Extinguishment', date: 'September 24, 2026',
    time: '3:30 PM - 5:00 PM Central Time', tags: ['Fire Containment', 'Emergency Board-up', 'State Farm Claim'], lead: '24', distance: '4.2 mi away', urgent: true,
    image: 'https://images.unsplash.com/photo-1632759145351-1d592919f522?auto=format&fit=crop&w=720&q=85'
  }
];

const projects = [
  { name:'Sarah Jenkins', address:'77002 Downtown Metro / Buffalo Bayou Park, Houston, TX 77002', job:'Fire & Smoke Containment', cause:'Cause: Localized Electrical Fire', schedule:'Tomorrow, Oct 24 · 12:00 PM - 4:00 PM', note:'Assigned: Crew Alpha-3 (4 Techs)', type:'Primary Contact', value:'(555) 882-2054', tags:['Fire & Smoke Containment','Rafter Shearing','HEPA Scrubbing'] },
  { name:'Abdullah Ramzan', address:'4020 Mitchford Dr, St. Louis / Houston Service Perimeter', job:'Drain Cleaning + Sewage Clean-up', cause:'Cause: Drain or Sewer Backup', schedule:'Today · 1:00 PM - 4:00 PM', note:'Assigned: Squad Delta (3 Techs)', type:'Direct Commercial Pay', value:'$6,850.00', tags:['Drain Cleaning','Sewage Clean-up','Antimicrobial Wash'] },
  { name:'Elena Rostova', address:'1422 Memorial Drive, Houston, TX 77024', job:'Large Commercial Project / Tree Removal', cause:'Cause: Storm Damage', schedule:'Started 9:00 AM Today', note:'Assigned: Heavy Lift Bravo (6 Techs)', type:'Insurance Claim', value:'$18,400.00', tags:['60-Ton Crane Lift','Heat-Shrink Tarping','Truss Shoring'] },
  { name:'David Chen', address:'2810 Westheimer Rd, Unit 4B, Houston, TX 77063', job:'Water Damage & Subfloor Drying', cause:'Cause: Plumbing Pipe Rupture', schedule:'Active · Daily Moisture Audit', note:'Assigned: Tech Unit 2 (2 Techs)', type:'Insurance Claim', value:'$9,750.00', tags:['LGR Dehumidification','Thermal Infrared Mapping','Mat Drying'] }
];

const customers = [
  ['SJ','Sarah Jenkins','4218 Memorial Dr, Houston, TX','Residential','Water Extraction & Drying','Oct 24, 2024','$14,920.00','Paid'],
  ['AR','Abdullah Ramzan','Apex Logistics, Westheimer Rd','Commercial','Sewage Clean-up & Sanitization','Sep 28, 2024','$8,970.00','Partial'],
  ['EV','Elena Vance','17802 Bridgeland Prairie, Cypress','Residential','Mold Remediation & Reconstruction','Aug 19, 2024','$42,050.00','Paid'],
  ['DS','David Sterling','Sterling Commercial Properties','Commercial','Sprinkler Rupture Emergency Dryout','Jun 04, 2024','$12,700.00','Pending'],
  ['MZ','Miriam C. Zhao','902 Westcott St, Unit 4B','Residential','Supply Line Break Recovery','Mar 11, 2024','$2,440.00','Paid']
];

const users = [
  ['DB','Dubu Bulman','Field Tech','Free','dubu19@gmail.com','+1 (555) 443-2191','online'],
  ['TC','Tim Clynes','Disaster Specialist','Free','clynes77@gmail.com','+1 (555) 447-7552','online'],
  ['TW','Triple Win Solutions','Partner Contractor','Free','support@triplewinnersllc.org','+1 (555) 870-1720','online'],
  ['WI','Waheed Imran','Field Supervisor','Free','imran.ops@reliefsync.io','+1 (555) 230-4914','away'],
  ['JC','Jessica Conn','Emergency Electrician','Working','jessica.tec@yahoo.com','+1 (555) 602-5341','online'],
  ['MB','Marcus Brody','External Contractor','','mbrody@brodyrestoration.com','+1 (555) 754-2041','offline']
];

const services = [
  ['Appliance Repair','Refrigerators, washers, dishwashers, etc.',''],
  ['Drain Cleaning','Hydro-jetting, augering','warning'],
  ['Mold Remediation','HEPA scrub, mold wrap, post tests',''],
  ['Reconstruction','Drywall, flooring, structural repair','selected'],
  ['Sewage Clean-up','Bio cleanup + black water extraction','selected'],
  ['Water Clean-up & Drying','LGR drying, water extraction for structures','selected'],
  ['Fire & Smoke Containment','Soot mitigation, odor cleaning, primary response',''],
  ['Emergency Roof Tarping & Board-up','Install weather tarps, window boarding, site secure',''],
  ['Biohazard & HazMat Remediation','Chemical spill, pathogens, propane, ERS certification required','warning']
];

window.AdminData = Object.freeze({
  navGroups,
  opportunities,
  projects,
  customers,
  users,
  services
});
})();
